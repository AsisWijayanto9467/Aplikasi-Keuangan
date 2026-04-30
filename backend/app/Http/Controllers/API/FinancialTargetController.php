<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\FinancialTarget;
use App\Models\TargetSaving;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class FinancialTargetController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        try {
            $user = $request->user();

            $query = FinancialTarget::where('user_id', $user->id)
                ->with(['savings' => function ($q) {
                    $q->orderBy('saving_date', 'desc');
                }]);

            // Filter by status
            if ($request->has('status')) {
                $query->where('status', $request->status);
            }

            // Filter by category
            if ($request->has('category')) {
                $query->where('category', $request->category);
            }

            // Sort
            $sortBy = $request->get('sort_by', 'created_at');
            $sortOrder = $request->get('sort_order', 'desc');
            $query->orderBy($sortBy, $sortOrder);

            $targets = $query->paginate(10);

            return response()->json([
                'success' => true,
                'data' => $targets
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
            $user = $request->user();

            $validator = Validator::make($request->all(), [
                'title' => 'required|string|max:255',
                'category' => 'required|in:education,work,vacation,medical,emergency_fund,property,vehicle,business,wedding,other',
                'reason' => 'required|string|max:1000',
                'target_amount' => 'required|numeric|min:1000',
                'target_date' => 'required|date|after:today',
                'icon' => 'nullable|string',
                'notes' => 'nullable|string'
            ], [
                'reason.required' => 'Alasan menabung harus diisi',
                'target_amount.min' => 'Target minimal adalah Rp 1.000',
                'target_date.after' => 'Tanggal target harus setelah hari ini'
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'errors' => $validator->errors()
                ], 422);
            }

            $target = FinancialTarget::create([
                'user_id' => $user->id,
                'title' => $request->title,
                'category' => $request->category,
                'reason' => $request->reason,
                'target_amount' => $request->target_amount,
                'current_amount' => 0,
                'target_date' => $request->target_date,
                'status' => 'active',
                'icon' => $request->icon,
                'notes' => $request->notes
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Target finansial berhasil dibuat',
                'data' => $target
            ], 201);
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
    public function show(Request $request, string $id)
    {
        try {
            $user = $request->user();

            $target = FinancialTarget::where('user_id', $user->id)
                ->with(['savings' => function ($q) {
                    $q->orderBy('saving_date', 'desc');
                }])
                ->findOrFail($id);

            return response()->json([
                'success' => true,
                'data' => $target
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public  function addSaving(Request $request, $targetId)
    {
        try {
            $user =  $request->user();

            $validator = Validator::make($request->all(), [
                'amount' => 'required|numeric|min:1000',
                'saving_date' => 'required|date|before_or_equal:today',
                'notes' => 'nullable|string|max:500'
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'errors' => $validator->errors()
                ], 422);
            }

            $target = FinancialTarget::where('user_id', $user->id)
                ->findOrFail($targetId);

            if ($target->status !== 'active') {
                return response()->json([
                    'success' => false,
                    'message' => 'Target ini sudah tidak aktif'
                ], 400);
            }

            $saving = TargetSaving::create([
                'financial_target_id' => $target->id,
                'user_id' => $user->id,
                'amount' => $request->amount,
                'saving_date' => $request->saving_date,
                'notes' => $request->notes
            ]);

            $newAmount = $target->current_amount + $request->amount;
            $updateData = ['current_amount' => $newAmount];

            if ($newAmount >= $target->target_amount) {
                $updateData['status'] = 'completed';
            }

            $target->update($updateData);

            return response()->json([
                'success' => true,
                'message' => 'Setoran berhasil ditambahkan',
                'data' => [
                    'saving' => $saving,
                    'target' => $target->fresh()
                ]
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function getProgressData(Request $request, $targetId)
    {
        try {
            $user = $request->user();

            $target = FinancialTarget::where('user_id', $user->id)
                ->with(['savings' => function ($q) {
                    $q->orderBy('saving_date', 'asc');
                }])
                ->findOrFail($targetId);

            // Generate data untuk chart
            $chartData = $this->generateChartData($target);

            return response()->json([
                'success' => true,
                'data' => [
                    'target' => $target,
                    'chart' => $chartData,
                    'statistics' => $this->getTargetStatistics($target)
                ]
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function getSummary(Request $request)
    {
        try {
            $userId = $request->user();

            $summary = [
                'total_active' => FinancialTarget::where('user_id', $userId)->active()->count(),
                'total_completed' => FinancialTarget::where('user_id', $userId)->completed()->count(),
                'total_target_amount' => FinancialTarget::where('user_id', $userId)->active()->sum('target_amount'),
                'total_saved_amount' => FinancialTarget::where('user_id', $userId)->active()->sum('current_amount'),
                'overall_progress' => 0,
                'targets' => FinancialTarget::where('user_id', $userId)
                    ->active()
                    ->orderBy('target_date', 'asc')
                    ->get()
                    ->map(function ($target) {
                        return [
                            'id' => $target->id,
                            'title' => $target->title,
                            'category' => $target->category,
                            'progress' => $target->progress_percentage,
                            'remaining_days' => $target->remaining_days,
                            'status' => $target->is_overdue ? 'overdue' : 'on_track'
                        ];
                    })
            ];

            $totalTarget = $summary['total_target_amount'];
            if ($totalTarget > 0) {
                $summary['overall_progress'] = round(($summary['total_saved_amount'] / $totalTarget) * 100, 2);
            }

            return response()->json([
                'success' => true,
                'data' => $summary
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function cancel(Request $request, $targetId) {
        try {
            $user = $request->user();
            
            $target = FinancialTarget::where('user_id', $user->id)
                ->active()
                ->findOrFail($targetId);

            $target->update(['status' => 'cancelled']);

            return response()->json([
                'success' => true,
                'message' => 'Target finansial dibatalkan'
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
    public function destroy(string $id)
    {
        try {
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    private function generateChartData($target)
    {
        $chartData = [
            'labels' => [],
            'datasets' => [
                [
                    'label' => 'Target Amount',
                    'data' => [],
                    'borderColor' => '#4CAF50',
                    'fill' => false
                ],
                [
                    'label' => 'Current Savings',
                    'data' => [],
                    'borderColor' => '#2196F3',
                    'fill' => true
                ]
            ]
        ];

        $startDate = Carbon::parse($target->created_at);
        $endDate = Carbon::parse($target->target_date);

        $cumulativeAmount = 0;
        $months = [];

        while ($startDate <= $endDate) {
            $monthKey = $startDate->format('Y-m');
            $months[] = $startDate->format('M Y');

            // Get savings for this month
            $monthlySavings = $target->savings
                ->where('saving_date', '>=', $startDate->startOfMonth())
                ->where('saving_date', '<=', $startDate->endOfMonth())
                ->sum('amount');

            $cumulativeAmount += $monthlySavings;

            $chartData['datasets'][0]['data'][] = $target->target_amount;
            $chartData['datasets'][1]['data'][] = $cumulativeAmount;

            $startDate->addMonth();
        }

        $chartData['labels'] = $months;

        return $chartData;
    }

    private function getTargetStatistics($target)
    {
        $totalDays = Carbon::parse($target->created_at)->diffInDays(Carbon::parse($target->target_date));
        $daysPassed = Carbon::parse($target->created_at)->diffInDays(Carbon::now());
        $daysPercentage = $totalDays > 0 ? ($daysPassed / $totalDays) * 100 : 0;

        $recommendedMonthlySaving = $totalDays > 0
            ? ($target->remaining_amount / max(1, $target->remaining_days)) * 30
            : 0;

        return [
            'daily_average' => $daysPassed > 0 ? round($target->current_amount / $daysPassed, 2) : 0,
            'time_progress' => round($daysPercentage, 2),
            'amount_progress' => $target->progress_percentage,
            'on_track' => $target->progress_percentage >= $daysPercentage,
            'recommended_monthly_saving' => round($recommendedMonthlySaving, 2),
            'days_remaining' => max(0, $target->remaining_days)
        ];
    }
}
