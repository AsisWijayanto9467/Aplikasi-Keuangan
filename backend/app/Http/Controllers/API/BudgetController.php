<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Budget;
use App\Models\BudgetTransaction;
use App\Models\Category;
use App\Models\MonthlyIncome;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class BudgetController extends Controller
{
    public function setupMonthlyBudget(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'total_income' => 'required|numeric|min:0',
            'month' => 'required|integer|between:1,12',
            'year' => 'required|integer|min:2024|max:2099',
            'budgets' => 'required|array|min:1',
            'budgets.*.category_id' => 'required|exists:categories,id',
            'budgets.*.limit_amount' => 'required|numeric|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();
            $totalBudget = collect($request->budgets)->sum('limit_amount');

            // Validasi total budget tidak melebihi income
            if ($totalBudget > $request->total_income) {
                return response()->json([
                    'success' => false,
                    'message' => 'Total budget (Rp ' . number_format($totalBudget, 0, ',', '.') . ') melebihi pemasukan (Rp ' . number_format($request->total_income, 0, ',', '.') . ')',
                    'remaining_unallocated' => $request->total_income - $totalBudget
                ], 422);
            }

            // Validasi kategori yang dipilih adalah expense
            $expenseCategories = Category::where('type', 'expense')->pluck('id')->toArray();
            foreach ($request->budgets as $budget) {
                if (!in_array($budget['category_id'], $expenseCategories)) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Kategori ID ' . $budget['category_id'] . ' bukan kategori pengeluaran'
                    ], 422);
                }
            }

            // Setup atau update Monthly Income
            $monthlyIncome = MonthlyIncome::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'month' => $request->month,
                    'year' => $request->year,
                ],
                [
                    'total_income' => $request->total_income
                ]
            );

            // Process budgets
            $createdBudgets = [];
            $updatedBudgets = [];

            foreach ($request->budgets as $budgetData) {
                $budget = Budget::updateOrCreate(
                    [
                        'user_id' => $user->id,
                        'category_id' => $budgetData['category_id'],
                        'month' => $request->month,
                        'year' => $request->year,
                    ],
                    [
                        'limit_amount' => $budgetData['limit_amount']
                    ]
                );

                if ($budget->wasRecentlyCreated) {
                    $createdBudgets[] = $budget;
                } else {
                    $updatedBudgets[] = $budget;
                }
            }

            // Load budget dengan relasi
            $allBudgets = Budget::with('category')
                ->where('user_id', $user->id)
                ->where('month', $request->month)
                ->where('year', $request->year)
                ->get();

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Budget bulan ' . Carbon::createFromDate($request->year, $request->month, 1)->format('F Y') . ' berhasil disetup',
                'data' => [
                    'income' => $monthlyIncome->fresh(),
                    'budgets' => $allBudgets->map(function ($budget) {
                        return [
                            'id' => $budget->id,
                            'category_id' => $budget->category_id,
                            'category_name' => $budget->category->name,
                            'limit_amount' => $budget->limit_amount,
                            'total_spent' => $budget->total_spent,
                            'remaining_amount' => $budget->remaining_amount,
                            'usage_percentage' => $budget->usage_percentage,
                            'status' => $budget->status,
                            'month' => $budget->month,
                            'year' => $budget->year,
                        ];
                    }),
                    'summary' => [
                        'total_income' => $monthlyIncome->total_income,
                        'total_budget' => $monthlyIncome->total_budget,
                        'total_spent' => $monthlyIncome->total_spent,
                        'unallocated_amount' => $monthlyIncome->unallocated_amount,
                        'remaining_balanced' => $monthlyIncome->remaining_balanced,
                        'budget_usage_percentage' => $monthlyIncome->budget_usage_percentage,
                    ]
                ]
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal setup budget: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get budget overview bulan tertentu
     * GET /api/budget/overview?month=4&year=2026
     */
    public function getBudgetOverview(Request $request)
    {
        $month = $request->input('month', now()->month);
        $year = $request->input('year', now()->year);
        $user = $request->user();

        $monthlyIncome = MonthlyIncome::where('user_id', $user->id)
            ->where('month', $month)
            ->where('year', $year)
            ->first();

        $budgets = Budget::with('category')
            ->where('user_id', $user->id)
            ->where('month', $month)
            ->where('year', $year)
            ->get();

        // Hitung total transaksi hari ini
        $todaySpent = BudgetTransaction::where('user_id', $user->id)
            ->whereDate('date', now()->format('Y-m-d'))
            ->sum('amount');

        // Budget dengan penggunaan tertinggi
        $mostUsedBudget = $budgets->sortByDesc('usage_percentage')->first();
        $almostExceeded = $budgets->where('usage_percentage', '>=', 90)
            ->where('usage_percentage', '<', 100);

        return response()->json([
            'success' => true,
            'data' => [
                'month' => $month,
                'year' => $year,
                'month_label' => Carbon::createFromDate($year, $month, 1)->format('F Y'),
                'income' => $monthlyIncome ? [
                    'total_income' => $monthlyIncome->total_income,
                    'total_budget' => $monthlyIncome->total_budget,
                    'total_spent' => $monthlyIncome->total_spent,
                    'unallocated_amount' => $monthlyIncome->unallocated_amount,
                    'remaining_balanced' => $monthlyIncome->remaining_balanced,
                    'budget_usage_percentage' => $monthlyIncome->budget_usage_percentage,
                    'daily_recommendation' => $monthlyIncome->daily_recommendation,
                ] : null,
                'today_spent' => $todaySpent,
                'budgets' => $budgets->map(function ($budget) {
                    return [
                        'id' => $budget->id,
                        'category_id' => $budget->category_id,
                        'category_name' => $budget->category->name,
                        'limit_amount' => $budget->limit_amount,
                        'total_spent' => $budget->total_spent,
                        'remaining_amount' => $budget->remaining_amount,
                        'usage_percentage' => $budget->usage_percentage,
                        'status' => $budget->status,
                        'remaining_days' => $budget->remaining_days,
                        'daily_recommendation' => $budget->daily_recommendation,
                        'average_daily_spent' => $budget->average_daily_spent,
                    ];
                }),
                'alerts' => [
                    'almost_exceeded' => $almostExceeded->map(function ($budget) {
                        return [
                            'category_name' => $budget->category->name,
                            'usage_percentage' => $budget->usage_percentage,
                            'remaining_amount' => $budget->remaining_amount,
                        ];
                    })->values(),
                    'most_used_budget' => $mostUsedBudget ? [
                        'category_name' => $mostUsedBudget->category->name,
                        'usage_percentage' => $mostUsedBudget->usage_percentage,
                    ] : null,
                ]
            ]
        ]);
    }

    /**
     * Add transaction (pengeluaran)
     * POST /api/budget/transactions
     */
    public function addTransaction(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'category_id' => 'required|exists:categories,id',
            'amount' => 'required|numeric|min:1',
            'description' => 'required|string|max:255',
            'date' => 'required|date',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();
            $category = Category::findOrFail($request->category_id);

            // Validasi kategori expense
            if ($category->type !== 'expense') {
                return response()->json([
                    'success' => false,
                    'message' => 'Kategori ini bukan untuk pengeluaran'
                ], 422);
            }

            // Validasi budget untuk periode transaksi
            $transactionDate = Carbon::parse($request->date);
            $budget = Budget::where('user_id', $user->id)
                ->where('category_id', $request->category_id)
                ->where('month', $transactionDate->month)
                ->where('year', $transactionDate->year)
                ->first();

            if (!$budget) {
                return response()->json([
                    'success' => false,
                    'message' => 'Budget untuk kategori "' . $category->name . '" pada ' . $transactionDate->format('F Y') . ' belum disetup',
                ], 422);
            }

            // Hitung total pengeluaran yang ada
            $totalSpent = BudgetTransaction::where('user_id', $user->id)
                ->where('category_id', $request->category_id)
                ->whereMonth('date', $transactionDate->month)
                ->whereYear('date', $transactionDate->year)
                ->sum('amount');

            $newTotal = $totalSpent + $request->amount;

            // Validasi tidak melebihi budget
            if ($newTotal > $budget->limit_amount) {
                $remaining = $budget->limit_amount - $totalSpent;
                return response()->json([
                    'success' => false,
                    'message' => 'Transaksi gagal! Budget ' . $category->name . ' tersisa Rp ' . number_format($remaining, 0, ',', '.'),
                    'data' => [
                        'remaining_budget' => $remaining,
                        'requested_amount' => $request->amount,
                        'exceed_amount' => $request->amount - $remaining,
                    ]
                ], 422);
            }

            // Simpan transaksi
            $transaction = BudgetTransaction::create([
                'user_id' => $user->id,
                'category_id' => $request->category_id,
                'amount' => $request->amount,
                'description' => $request->description,
                'date' => $request->date,
            ]);

            DB::commit();

            // Refresh budget untuk mendapatkan data terbaru
            $updatedBudget = $budget->fresh();

            return response()->json([
                'success' => true,
                'message' => 'Transaksi berhasil dicatat',
                'data' => [
                    'transaction' => [
                        'id' => $transaction->id,
                        'category_name' => $category->name,
                        'amount' => $transaction->amount,
                        'formatted_amount' => $transaction->formatted_amount,
                        'description' => $transaction->description,
                        'date' => $transaction->date->format('Y-m-d'),
                        'formatted_date' => $transaction->formatted_date,
                    ],
                    'budget_remaining' => [
                        'limit_amount' => $updatedBudget->limit_amount,
                        'total_spent' => $updatedBudget->total_spent,
                        'remaining_amount' => $updatedBudget->remaining_amount,
                        'usage_percentage' => $updatedBudget->usage_percentage,
                        'status' => $updatedBudget->status,
                        'daily_recommendation' => $updatedBudget->daily_recommendation,
                    ]
                ]
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();

            // Cek jika error dari validasi budget di model
            if (str_contains($e->getMessage(), '⚠️')) {
                return response()->json([
                    'success' => false,
                    'message' => $e->getMessage()
                ], 422);
            }

            return response()->json([
                'success' => false,
                'message' => 'Gagal mencatat transaksi: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get daftar transaksi
     * GET /api/budget/transactions?month=4&year=2026&category_id=1&page=1
     */
    public function getTransactions(Request $request)
    {
        $user = $request->user();

        $query = BudgetTransaction::where('user_id', $user->id)
            ->with('category');

        // Filter
        if ($request->month && $request->year) {
            $query->whereMonth('date', $request->month)
                ->whereYear('date', $request->year);
        }

        if ($request->category_id) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->date) {
            $query->whereDate('date', $request->date);
        }

        if ($request->search) {
            $query->where('description', 'like', '%' . $request->search . '%');
        }

        $perPage = $request->per_page ?? 15;
        $transactions = $query->latest()->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => $transactions
        ]);
    }

    /**
     * Edit/Update single budget
     * PUT /api/budget/{id}
     */
    public function updateBudget(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'limit_amount' => 'required|numeric|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $user = $request->user();
            $budget = Budget::where('id', $id)
                ->where('user_id', $user->id)
                ->firstOrFail();

            // Validasi budget baru tidak kurang dari total yang sudah terpakai
            if ($request->limit_amount < $budget->total_spent) {
                return response()->json([
                    'success' => false,
                    'message' => 'Budget baru (Rp ' . number_format($request->limit_amount, 0, ',', '.') . ') tidak boleh kurang dari total pengeluaran (Rp ' . number_format($budget->total_spent, 0, ',', '.') . ')',
                ], 422);
            }

            // Validasi total budget + income
            $monthlyIncome = MonthlyIncome::where('user_id', $user->id)
                ->where('month', $budget->month)
                ->where('year', $budget->year)
                ->first();

            if ($monthlyIncome) {
                $otherBudgets = Budget::where('user_id', $user->id)
                    ->where('month', $budget->month)
                    ->where('year', $budget->year)
                    ->where('id', '!=', $budget->id)
                    ->sum('limit_amount');

                $newTotalBudget = $otherBudgets + $request->limit_amount;

                if ($newTotalBudget > $monthlyIncome->total_income) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Total budget akan melebihi pemasukan. Maksimal budget: Rp ' . number_format($monthlyIncome->total_income - $otherBudgets, 0, ',', '.'),
                    ], 422);
                }
            }

            $oldAmount = $budget->limit_amount;
            $budget->update([
                'limit_amount' => $request->limit_amount
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Budget berhasil diupdate dari Rp ' . number_format($oldAmount, 0, ',', '.') . ' menjadi Rp ' . number_format($request->limit_amount, 0, ',', '.'),
                'data' => [
                    'id' => $budget->id,
                    'category_name' => $budget->category->name,
                    'limit_amount' => $budget->limit_amount,
                    'total_spent' => $budget->total_spent,
                    'remaining_amount' => $budget->remaining_amount,
                    'usage_percentage' => $budget->usage_percentage,
                    'status' => $budget->status,
                ]
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Budget tidak ditemukan'
            ], 404);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal update budget: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Edit/Update Monthly Income
     * PUT /api/budget/income/update
     */
    public function updateIncome(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'total_income' => 'required|numeric|min:0',
            'month' => 'required|integer|between:1,12',
            'year' => 'required|integer|min:2024',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $user = $request->user();

            $monthlyIncome = MonthlyIncome::where('user_id', $user->id)
                ->where('month', $request->month)
                ->where('year', $request->year)
                ->first();

            if (!$monthlyIncome) {
                return response()->json([
                    'success' => false,
                    'message' => 'Income untuk bulan ini belum disetup'
                ], 404);
            }

            // Validasi income baru tidak kurang dari total budget
            $totalBudget = $monthlyIncome->total_budget;
            if ($request->total_income < $totalBudget) {
                return response()->json([
                    'success' => false,
                    'message' => 'Income baru (Rp ' . number_format($request->total_income, 0, ',', '.') . ') tidak boleh kurang dari total budget yang sudah dialokasikan (Rp ' . number_format($totalBudget, 0, ',', '.') . ')',
                    'current_budget_allocation' => $totalBudget
                ], 422);
            }

            $oldIncome = $monthlyIncome->total_income;
            $monthlyIncome->update([
                'total_income' => $request->total_income
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Income berhasil diupdate dari Rp ' . number_format($oldIncome, 0, ',', '.') . ' menjadi Rp ' . number_format($request->total_income, 0, ',', '.'),
                'data' => $monthlyIncome->fresh()
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal update income: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Reset budget bulanan (reset pengeluaran jadi 0, budget tetap)
     * POST /api/budget/reset/transactions
     */
    public function resetTransactions(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'month' => 'required|integer|between:1,12',
            'year' => 'required|integer|min:2024',
            'category_id' => 'nullable|exists:categories,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();

            $query = BudgetTransaction::where('user_id', $user->id)
                ->whereMonth('date', $request->month)
                ->whereYear('date', $request->year);

            // Jika ingin reset per kategori
            if ($request->category_id) {
                $query->where('category_id', $request->category_id);
            }

            $count = $query->count();

            if ($count === 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Tidak ada transaksi yang bisa direset',
                ], 404);
            }

            $query->delete();

            DB::commit();

            $message = $request->category_id
                ? 'Transaksi kategori berhasil direset'
                : 'Semua transaksi bulan ' . Carbon::createFromDate($request->year, $request->month, 1)->format('F Y') . ' berhasil direset';

            return response()->json([
                'success' => true,
                'message' => $message,
                'data' => [
                    'deleted_count' => $count,
                    'month' => $request->month,
                    'year' => $request->year,
                ]
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal mereset transaksi: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Reset seluruh budget (hapus budget + transaksi + income)
     * DELETE /api/budget/reset/all
     */
    public function resetAllBudget(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'month' => 'required|integer|between:1,12',
            'year' => 'required|integer|min:2024',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();
            $month = $request->month;
            $year = $request->year;

            // Hapus transaksi
            $deletedTransactions = BudgetTransaction::where('user_id', $user->id)
                ->whereMonth('date', $month)
                ->whereYear('date', $year)
                ->delete();

            // Hapus budgets
            $deletedBudgets = Budget::where('user_id', $user->id)
                ->where('month', $month)
                ->where('year', $year)
                ->delete();

            // Hapus income
            $deletedIncome = MonthlyIncome::where('user_id', $user->id)
                ->where('month', $month)
                ->where('year', $year)
                ->delete();

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Semua data budget bulan ' . Carbon::createFromDate($year, $month, 1)->format('F Y') . ' berhasil direset',
                'data' => [
                    'deleted_transactions' => $deletedTransactions,
                    'deleted_budgets' => $deletedBudgets,
                    'deleted_income' => $deletedIncome,
                ]
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal mereset data: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get daily budget recommendations
     * GET /api/budget/daily-recommendations?month=4&year=2026
     */
    public function getDailyRecommendations(Request $request)
    {
        $month = $request->input('month', now()->month);
        $year = $request->input('year', now()->year);
        $user = $request->user();

        $budgets = Budget::with('category')
            ->where('user_id', $user->id)
            ->where('month', $month)
            ->where('year', $year)
            ->get();

        $recommendations = $budgets->map(function ($budget) {
            return [
                'category_name' => $budget->category->name,
                'remaining_amount' => $budget->remaining_amount,
                'remaining_days' => $budget->remaining_days,
                'daily_recommendation' => $budget->daily_recommendation,
                'average_daily_spent' => $budget->average_daily_spent,
                'usage_percentage' => $budget->usage_percentage,
                'status' => $budget->status,
                'message' => $this->getBudgetMessage($budget),
            ];
        });

        $monthlyIncome = MonthlyIncome::where('user_id', $user->id)
            ->where('month', $month)
            ->where('year', $year)
            ->first();

        return response()->json([
            'success' => true,
            'data' => [
                'month' => Carbon::createFromDate($year, $month, 1)->format('F Y'),
                'overall_daily_recommendation' => $monthlyIncome ? $monthlyIncome->daily_recommendation : 0,
                'budgets' => $recommendations,
            ]
        ]);
    }

    /**
     * Helper: Get status message untuk budget
     */
    private function getBudgetMessage($budget)
    {
        switch ($budget->status) {
            case 'safe':
                return '✅ Budget aman, tetap hemat ya!';
            case 'moderate':
                return '⚠️ Budget sudah terpakai 50%, hati-hati dengan pengeluaran!';
            case 'warning':
                return '🔶 Budget sudah mencapai 70%, kurangi pengeluaran!';
            case 'danger':
                return '🔴 Budget hampir habis! Tersisa ' . $budget->usage_percentage . '%';
            case 'exceeded':
                return '❌ Budget sudah melebihi batas!';
            default:
                return '';
        }
    }

    /**
     * Delete/remove transaction
     * DELETE /api/budget/transactions/{id}
     */
    public function deleteTransaction(Request $request, $id)
    {
        try {
            $user = $request->user();
            $transaction = BudgetTransaction::where('id', $id)
                ->where('user_id', $user->id)
                ->firstOrFail();

            $transaction->delete();

            return response()->json([
                'success' => true,
                'message' => 'Transaksi berhasil dihapus',
            ]);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan'
            ], 404);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal menghapus transaksi: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get budget history per bulan
     * GET /api/budget/history?limit=6
     */
    public function getBudgetHistory(Request $request)
    {
        $user = $request->user();
        $limit = $request->input('limit', 12);

        $history = MonthlyIncome::where('user_id', $user->id)
            ->orderBy('year', 'desc')
            ->orderBy('month', 'desc')
            ->limit($limit)
            ->get()
            ->map(function ($income) {
                return [
                    'month' => $income->month,
                    'year' => $income->year,
                    'month_label' => $income->month_label,
                    'total_income' => $income->total_income,
                    'total_budget' => $income->total_budget,
                    'total_spent' => $income->total_spent,
                    'remaining_balanced' => $income->remaining_balanced,
                    'budget_usage_percentage' => $income->budget_usage_percentage,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $history
        ]);
    }
}
