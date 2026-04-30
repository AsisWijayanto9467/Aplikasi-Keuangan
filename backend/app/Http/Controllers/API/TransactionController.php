<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Balance;
use App\Models\Category;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class TransactionController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        try {
            $user = $request->user();

            $query = Transaction::with('category')
                ->where('user_id', $user->id);

            if ($request->has('type')) {
                $query->where('type', $request->type);
            }

            if ($request->has('category_id')) {
                $query->where('category_id', $request->category_id);
            }

            if ($request->has('start_date')) {
                $query->whereDate('date', '>=', $request->start_date);
            }
            if ($request->has('end_date')) {
                $query->whereDate('date', '<=', $request->end_date);
            }

            $query->orderBy('date', 'desc');
            $transactions = $query->paginate(10);

            return response()->json([
                'message' => 'Riwayat transaksi',
                'data' => $transactions
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function statistics(Request $request)
    {
        try {
            $user = $request->user();
            $period = $request->get('period', 'month');
            $year = $request->get('year', date('Y'));
            $month = $request->get('month', date('m'));

            $categoryStats = Transaction::with('category')
                ->where('user_id', $user->id)
                ->whereYear('date', $year)
                ->when($period == 'month', function($query) use ($month) {
                    return $query->whereMonth('date', $month);
                })
                ->selectRaw('category_id, type, SUM(amount) as total_amount')
                ->groupBy('category_id', 'type')
                ->get();

            $expenseByCategory = [];
            $incomeByCategory = [];

            foreach ($categoryStats as $stat) {
                $categoryName = $stat->category->name ?? 'Lainnya';
                $categoryIcon = $stat->category->icon ?? '📊';
                $categoryColor = $stat->category->color ?? '#64748B';

                if ($stat->type == 'expense') {
                    $expenseByCategory[] = [
                        'category' => $categoryName,
                        'icon' => $categoryIcon,
                        'color' => $categoryColor,
                        'amount' => (float) $stat->total_amount
                    ];
                } else {
                    $incomeByCategory[] = [
                        'category' => $categoryName,
                        'icon' => $categoryIcon,
                        'color' => $categoryColor,
                        'amount' => (float) $stat->total_amount
                    ];
                }
            }

            // Query untuk bar chart (trend harian/bulanan)
            $trendData = [];

            if ($period == 'month') {
                // Data per hari dalam bulan ini
                $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
                for ($day = 1; $day <= $daysInMonth; $day++) {
                    $date = sprintf('%s-%s-%02d', $year, $month, $day);

                    $dailyIncome = Transaction::where('user_id', $user->id)
                        ->whereDate('date', $date)
                        ->where('type', 'income')
                        ->sum('amount');

                    $dailyExpense = Transaction::where('user_id', $user->id)
                        ->whereDate('date', $date)
                        ->where('type', 'expense')
                        ->sum('amount');

                    $trendData[] = [
                        'label' => (string) $day,
                        'income' => (float) $dailyIncome,
                        'expense' => (float) $dailyExpense
                    ];
                }
            } else {
                // Data per bulan dalam tahun ini
                for ($monthNum = 1; $monthNum <= 12; $monthNum++) {
                    $monthlyIncome = Transaction::where('user_id', $user->id)
                        ->whereYear('date', $year)
                        ->whereMonth('date', $monthNum)
                        ->where('type', 'income')
                        ->sum('amount');

                    $monthlyExpense = Transaction::where('user_id', $user->id)
                        ->whereYear('date', $year)
                        ->whereMonth('date', $monthNum)
                        ->where('type', 'expense')
                        ->sum('amount');

                    $monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

                    $trendData[] = [
                        'label' => $monthNames[$monthNum - 1],
                        'income' => (float) $monthlyIncome,
                        'expense' => (float) $monthlyExpense
                    ];
                }
            }

            // Total summary
            $totalIncome = Transaction::where('user_id', $user->id)
                ->whereYear('date', $year)
                ->when($period == 'month', function($query) use ($month) {
                    return $query->whereMonth('date', $month);
                })
                ->where('type', 'income')
                ->sum('amount');

            $totalExpense = Transaction::where('user_id', $user->id)
                ->whereYear('date', $year)
                ->when($period == 'month', function($query) use ($month) {
                    return $query->whereMonth('date', $month);
                })
                ->where('type', 'expense')
                ->sum('amount');

            // Persentase pengeluaran vs pemasukan
            $totalTransactions = $totalIncome + $totalExpense;
            $incomePercentage = $totalTransactions > 0 ? ($totalIncome / $totalTransactions) * 100 : 0;
            $expensePercentage = $totalTransactions > 0 ? ($totalExpense / $totalTransactions) * 100 : 0;

            return response()->json([
                'message' => 'Data statistik',
                'data' => [
                    'period' => $period,
                    'year' => (int) $year,
                    'month' => $period == 'month' ? (int) $month : null,
                    'summary' => [
                        'total_income' => (float) $totalIncome,
                        'total_expense' => (float) $totalExpense,
                        'net_cashflow' => (float) ($totalIncome - $totalExpense),
                        'income_percentage' => round($incomePercentage, 2),
                        'expense_percentage' => round($expensePercentage, 2)
                    ],
                    'expense_by_category' => $expenseByCategory,
                    'income_by_category' => $incomeByCategory,
                    'trend_data' => $trendData
                ]
            ]);

        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }
    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        try {
            //
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        try {
            $request->validate([
                'category_id' => 'required|exists:categories,id',
                'title' => 'required|string|max:255',
                'description' => 'nullable|string',
                'amount' => 'required|numeric|min:1',
                'payment_method' => 'required|in:cash,qris,transfer',
                'type' => 'required|in:income,expense',
                'date' => 'required|date'
            ]);

            $user = $request->user();

            $category = Category::find($request->category_id);

            if ($category->type !== $request->type) {
                return response()->json([
                    'message' => 'Tipe kategori tidak sesuai dengan transaksi'
                ], 400);
            }

            DB::transaction(function () use ($request, $user, &$transaction) {

                $transaction = Transaction::create([
                    'user_id' => $user->id,
                    'category_id' => $request->category_id,
                    'title' => $request->title,
                    'description' => $request->description,
                    'amount' => $request->amount,
                    'type' => $request->type,
                    'payment_method' => $request->payment_method,
                    'date' => $request->date,
                ]);

                $balance = Balance::firstOrCreate(
                    ['user_id' => $user->id],
                    ['balance' => 0, 'is_initialized' => true]
                );

                if ($request->type == 'expense' && $balance->balance < $request->amount) {
                    return response()->json([
                        'message' => 'Saldo tidak mencukupi'
                    ], 400);
                }

                if ($request->type == 'income') {
                    $balance->balance += $request->amount;
                } else {
                    $balance->balance -= $request->amount;
                }

                $balance->save();
            });

            return response()->json([
                'message' => 'Transaksi berhasil ditambahkan',
                'data' => $transaction
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id, Request $request)
    {
        try {
            $user = $request->user();

            // 🔍 Ambil transaksi milik user + relasi kategori
            $transaction = Transaction::with('category')
                ->where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            return response()->json([
                'message' => 'Detail transaksi',
                'data' => $transaction
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(string $id)
    {
        try {
            //
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        try {
            $request->validate([
                'category_id' => 'required|exists:categories,id',
                'title' => 'required|string|max:255',
                'description' => 'nullable|string',
                'amount' => 'required|numeric|min:1',
                'payment_method' => 'required|in:cash,qris,transfer',
                'type' => 'required|in:income,expense',
                'date' => 'required|date'
            ]);

            $user = $request->user();

            $transaction = Transaction::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            $category = Category::find($request->category_id);

            if ($category->type !== $request->type) {
                return response()->json([
                    'message' => 'Tipe kategori tidak sesuai'
                ], 400);
            }

            DB::transaction(function () use ($request, $transaction) {

                $balance = Balance::where('user_id', $transaction->user_id)->first();

                // 🔁 rollback transaksi lama
                if ($transaction->type == 'income') {
                    $balance->balance -= $transaction->amount;
                } else {
                    $balance->balance += $transaction->amount;
                }

                $transaction->update([
                    'category_id' => $request->category_id,
                    'title' => $request->title,
                    'description' => $request->description,
                    'amount' => $request->amount,
                    'type' => $request->type,
                    'payment_method' => $request->payment_method,
                    'date' => $request->date,
                ]);

                if ($request->type == 'income') {
                    $balance->balance += $request->amount;
                } else {
                    $balance->balance -= $request->amount;
                }

                $balance->save();
            });

            return response()->json([
                'message' => 'Transaksi berhasil diupdate',
                'data' => $transaction
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id, Request $request)
    {
        try {
            $user = $request->user();

            $transaction = Transaction::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            DB::transaction(function () use ($transaction) {

                $balance = Balance::where('user_id', $transaction->user_id)->first();

                if ($transaction->type == 'income') {
                    $balance->balance -= $transaction->amount;
                } else {
                    $balance->balance += $transaction->amount;
                }

                $balance->save();

                $transaction->delete();
            });

            return response()->json([
                'message' => 'Transaksi berhasil dihapus'
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }
}
