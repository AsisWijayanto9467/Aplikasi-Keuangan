<?php

use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\BalanceController;
use App\Http\Controllers\API\BudgetController;
use App\Http\Controllers\API\CategoryController;
use App\Http\Controllers\API\TransactionController;
use Illuminate\Support\Facades\Route;

Route::prefix("v1")->group(function() {
    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/login', [AuthController::class, 'login']);

        Route::middleware("auth:sanctum")->group(function() {
            Route::post('/set-pin', [AuthController::class, 'setPin']);
            Route::post('/verify-pin', [AuthController::class, 'verifyPin']);
            Route::post('/logout', [AuthController::class, 'logout']);
            Route::get('/user', [AuthController::class, 'getUser']);
            Route::put('/user/update', [AuthController::class, 'updateUser']);
        });
    });

    Route::middleware("auth:sanctum")->group(function() {
        Route::get("/balance", [BalanceController::class, "checkBalance"]);
        Route::post("/balance", [BalanceController::class, "setInitialBalance"]);
    });

    Route::middleware(['auth:sanctum', 'balance'], )->group(function () {
        Route::get('/statistics', [TransactionController::class, 'statistics'])->middleware('auth:sanctum');

        Route::prefix("transactions")->group(function() {
            Route::get('/', [TransactionController::class, 'index']);
            Route::post('/', [TransactionController::class, 'store']);
            Route::put('/{id}', [TransactionController::class, 'update']);
            Route::delete('/{id}', [TransactionController::class, 'destroy']);
            Route::get('/{id}', [TransactionController::class, 'show']);
        });

        Route::prefix("categories")->group(function() {
            Route::post('/', [CategoryController::class, 'store']);
            Route::get('/', [CategoryController::class, 'index']);
            Route::get('/{id}', [CategoryController::class, 'show']);
            Route::put('/{id}', [CategoryController::class, 'update']);
            Route::delete('/{id}', [CategoryController::class, 'destroy']);
        });

        Route::prefix("budgets")->group(function() {
            Route::post('/', [BudgetController::class, 'store']);
            Route::get('/', [BudgetController::class, 'index']);
            Route::get('/{id}', [BudgetController::class, 'show']);
            Route::put('/{id}', [BudgetController::class, 'update']);
            Route::delete('/{id}', [BudgetController::class, 'destroy']);
            Route::get('/status', [BudgetController::class, 'checkStatus']);
        });
    });
});
