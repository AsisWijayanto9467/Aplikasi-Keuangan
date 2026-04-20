<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Budget;
use App\Models\Transaction;
use Illuminate\Http\Request;

class BudgetController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        try {
            $user = $request->user();

            $budgets = Budget::with('category')
                ->where('user_id', $user->id)
                ->get()
                ->map(function ($budget) {

                    // hitung total pengeluaran
                    $spent = Transaction::where('user_id', $budget->user_id)
                        ->where('category_id', $budget->category_id)
                        ->where('type', 'expense')
                        ->whereMonth('date', $budget->month)
                        ->whereYear('date', $budget->year)
                        ->sum('amount');

                    return [
                        'id' => $budget->id,
                        'category' => $budget->category->name,
                        'limit' => $budget->limit_amount,
                        'spent' => $spent,
                        'remaining' => $budget->limit_amount - $spent,
                        'month' => $budget->month,
                        'year' => $budget->year,
                    ];
                });

            return response()->json($budgets);

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
                'limit_amount' => 'required|numeric',
                'month' => 'required|integer',
                'year' => 'required|integer',
            ]);

            $user = $request->user();

            $budget = Budget::create([
                'user_id' => $user->id,
                'category_id' => $request->category_id,
                'limit_amount' => $request->limit_amount,
                'month' => $request->month,
                'year' => $request->year,
            ]);

            return response()->json([
                'message' => 'Budget berhasil dibuat',
                'data' => $budget
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

            $budget = Budget::with('category')
                ->where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$budget) {
                return response()->json(['message' => 'Tidak ditemukan'], 404);
            }

            return response()->json($budget);
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
            $user = $request->user();

            $budget = Budget::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$budget) {
                return response()->json(['message' => 'Tidak ditemukan'], 404);
            }

            $budget->update([
                'limit_amount' => $request->limit_amount ?? $budget->limit_amount,
                'month' => $request->month ?? $budget->month,
                'year' => $request->year ?? $budget->year,
            ]);

            return response()->json([
                'message' => 'Budget berhasil diupdate',
                'data' => $budget
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
    public function destroy(string $id,Request $request)
    {
        try {
            $user = $request->user();

            $budget = Budget::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$budget) {
                return response()->json(['message' => 'Tidak ditemukan'], 404);
            }

            $budget->delete();

            return response()->json([
                'message' => 'Budget berhasil dihapus'
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }
}
