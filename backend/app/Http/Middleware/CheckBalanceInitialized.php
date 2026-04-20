<?php

namespace App\Http\Middleware;

use App\Models\Balance;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckBalanceInitialized
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        $balance = Balance::where('user_id', $user->id)->first();

        if (!$balance || !$balance->is_initialized) {
            return response()->json([
                'message' => 'Saldo belum diinisialisasi'
            ], 403);
        }

        return $next($request);
    }
}
