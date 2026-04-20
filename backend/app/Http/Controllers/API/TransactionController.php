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

            // 🔍 FILTER TYPE (income / expense)
            if ($request->has('type')) {
                $query->where('type', $request->type);
            }

            // 🔍 FILTER BULAN & TAHUN
            if ($request->has('month') && $request->has('year')) {
                $query->whereMonth('date', $request->month)
                    ->whereYear('date', $request->year);
            }

            // 🔍 SORT TERBARU
            $query->orderBy('date', 'desc');

            // 📄 PAGINATION (10 data per halaman)
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

            // 🔍 Ambil kategori
            $category = Category::find($request->category_id);

            // ❌ Validasi: category harus sesuai type
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

            // 🔍 Ambil transaksi milik user
            $transaction = Transaction::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            // 🔍 Ambil kategori
            $category = Category::find($request->category_id);

            // ❌ Validasi category vs type
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

                // ✏️ update transaksi
                $transaction->update([
                    'category_id' => $request->category_id,
                    'title' => $request->title,
                    'description' => $request->description,
                    'amount' => $request->amount,
                    'type' => $request->type,
                    'payment_method' => $request->payment_method,
                    'date' => $request->date,
                ]);

                // ➕ apply transaksi baru
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

            // 🔍 Ambil transaksi milik user
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
