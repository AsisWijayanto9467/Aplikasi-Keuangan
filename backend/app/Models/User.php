<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    protected $table = "users";

    protected $fillable = [
        'name',
        'email',
        'phone',
        'gender',
        'birth_date',
        'password',
        "pin"
    ];

    protected $hidden = [
        'password'
    ];
    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function transactions()
    {
        return $this->hasMany(Transaction::class);
    }

    public function budgets() {
        return $this->hasMany(Budget::class);
    }

    public function monthlyIncomes() {
        return $this->hasMany(MonthlyIncome::class);
    }

    public function budgetTransactions()
    {
        return $this->hasMany(BudgetTransaction::class);
    }

    public function balance() {
        return $this->hasOne(Balance::class);
    }

    public function getCurrentMonthIncomeAttribute()
    {
        return $this->monthlyIncomes()
            ->where('month', now()->month)
            ->where('year', now()->year)
            ->first();
    }

    /**
     * Get current month's budgets
     */
    public function getCurrentMonthBudgetsAttribute()
    {
        return $this->budgets()
            ->where('month', now()->month)
            ->where('year', now()->year)
            ->get();
    }

    /**
     * Get today's transactions
     */
    public function getTodayTransactionsAttribute()
    {
        return $this->budgetTransactions()
            ->whereDate('date', now()->format('Y-m-d'))
            ->latest()
            ->get();
    }
}
