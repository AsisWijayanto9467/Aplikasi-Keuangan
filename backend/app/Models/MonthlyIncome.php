<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class MonthlyIncome extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'total_income',
        'month',
        'year'
    ];

    protected $casts = [
        'total_income' => 'decimal:2',
        'month' => 'integer',
        'year' => 'integer',
    ];

    /**
     * Relationship: MonthlyIncome belongs to User
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Accessor: Total budget yang sudah dialokasikan
     */
    public function getTotalBudgetAttribute()
    {
        return Budget::where('user_id', $this->user_id)
            ->where('month', $this->month)
            ->where('year', $this->year)
            ->sum('limit_amount');
    }

    /**
     * Accessor: Total pengeluaran bulan ini (dari semua transaksi)
     */
    public function getTotalSpentAttribute()
    {
        return BudgetTransaction::where('user_id', $this->user_id)
            ->whereMonth('date', $this->month)
            ->whereYear('date', $this->year)
            ->sum('amount');
    }

    /**
     * Accessor: Sisa uang yang belum dialokasikan
     */
    public function getUnallocatedAmountAttribute()
    {
        return $this->total_income - $this->total_budget;
    }

    /**
     * Accessor: Sisa uang yang belum terpakai (dari yang sudah dialokasikan)
     */
    public function getRemainingBalancedAttribute()
    {
        return $this->total_budget - $this->total_spent;
    }

    /**
     * Accessor: Persentase budget yang sudah terpakai
     */
    public function getBudgetUsagePercentageAttribute()
    {
        if ($this->total_budget > 0) {
            return round(($this->total_spent / $this->total_budget) * 100, 2);
        }
        return 0;
    }

    /**
     * Accessor: Label bulan (contoh: "April 2026")
     */
    public function getMonthLabelAttribute()
    {
        return Carbon::createFromDate($this->year, $this->month, 1)->format('F Y');
    }

    /**
     * Accessor: Rekomendasi pengeluaran harian (total remaining / sisa hari)
     */
    public function getDailyRecommendationAttribute()
    {
        $today = Carbon::now();
        $budgetDate = Carbon::createFromDate($this->year, $this->month, 1);
        $lastDay = $budgetDate->copy()->endOfMonth();

        $remainingDays = max(1, $today->diffInDays($lastDay, false) + 1);

        if ($this->remaining_balanced > 0) {
            return round($this->remaining_balanced / $remainingDays, 2);
        }

        return 0;
    }

    /**
     * Scope: Filter income bulan ini
     */
    public function scopeCurrentMonth($query)
    {
        return $query->where('month', now()->month)
            ->where('year', now()->year);
    }

    /**
     * Scope: Filter income berdasarkan bulan & tahun
     */
    public function scopeForMonth($query, $month, $year)
    {
        return $query->where('month', $month)
            ->where('year', $year);
    }

    /**
     * Scope: Filter income untuk user tertentu
     */
    public function scopeForUser($query, $userId)
    {
        return $query->where('user_id', $userId);
    }
}
