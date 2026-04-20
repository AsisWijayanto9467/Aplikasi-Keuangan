<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Balance;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BalanceController extends Controller
{
    public function checkBalance(Request $request)
    {
        $user = $request->user();
        $balance = Balance::where('user_id', $user->id)->first();

        // Jika balance tidak ada, buat default dengan is_initialized = false
        if (!$balance) {
            return response()->json([
                'initialized' => false,
                'balance' => 0
            ]);
        }

        return response()->json([
            'initialized' => $balance->is_initialized,
            'balance' => $balance->balance
        ]);
    }

    public function setInitialBalance(Request $request)
    {
        $request->validate([
            'amount' => 'required|numeric|min:0'
        ]);

        $user = $request->user();

        DB::transaction(function () use ($user, $request) {
            $balance = Balance::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'balance' => $request->amount,
                    'is_initialized' => true  // SELALU set true, bahkan untuk amount 0
                ]
            );
        });

        return response()->json([
            'message' => 'Saldo awal berhasil disimpan',
            'initialized' => true,
            'balance' => $request->amount
        ]);
    }
}
