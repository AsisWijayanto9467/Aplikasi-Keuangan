<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class Budget extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'limit_amount',
        'month',
        'year'
    ];

    protected $casts = [
        'limit_amount' => 'decimal:2',
        'month' => 'integer',
        'year' => 'integer',
    ];

    /**
     * Relationship: Budget belongs to User
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Relationship: Budget belongs to Category
     */
    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Relationship: Budget has many Budget Transactions (by category & month/year)
     */
    public function transactions()
    {
        return $this->hasMany(BudgetTransaction::class, 'category_id', 'category_id')
            ->where('user_id', $this->user_id)
            ->whereMonth('date', $this->month)
            ->whereYear('date', $this->year);
    }

    /**
     * Accessor: Total pengeluaran untuk budget ini
     */
    public function getTotalSpentAttribute()
    {
        return $this->transactions()->sum('amount');
    }

    /**
     * Accessor: Sisa budget
     */
    public function getRemainingAmountAttribute()
    {
        return $this->limit_amount - $this->total_spent;
    }

    /**
     * Accessor: Persentase pemakaian
     */
    public function getUsagePercentageAttribute()
    {
        if ($this->limit_amount > 0) {
            return round(($this->total_spent / $this->limit_amount) * 100, 2);
        }
        return 0;
    }

    /**
     * Accessor: Jumlah hari tersisa di bulan ini
     */
    public function getRemainingDaysAttribute()
    {
        $budgetDate = Carbon::createFromDate($this->year, $this->month, 1);
        $today = Carbon::now();

        // Jika bulan budget berbeda dengan bulan sekarang
        if ($today->format('Y-m') !== $budgetDate->format('Y-m')) {
            // Jika budget bulan depan, hitung total hari di bulan itu
            if ($today->lt($budgetDate)) {
                return $budgetDate->daysInMonth;
            }
            // Jika budget bulan lalu
            return 0;
        }

        // Budget bulan ini: hitung sisa hari
        $lastDayOfMonth = $budgetDate->copy()->endOfMonth();
        return max(0, $today->diffInDays($lastDayOfMonth, false) + 1); // +1 include today
    }

    /**
     * Accessor: Rekomendasi pengeluaran maksimal per hari
     */
    public function getDailyRecommendationAttribute()
    {
        $remainingDays = $this->remaining_days;

        if ($remainingDays > 0 && $this->remaining_amount > 0) {
            return round($this->remaining_amount / $remainingDays, 2);
        }

        return 0;
    }

    /**
     * Accessor: Status budget
     */
    public function getStatusAttribute()
    {
        $percentage = $this->usage_percentage;

        if ($percentage >= 100) return 'exceeded';
        if ($percentage >= 90) return 'danger';
        if ($percentage >= 70) return 'warning';
        if ($percentage >= 50) return 'moderate';
        return 'safe';
    }

    /**
     * Accessor: Rata-rata pengeluaran per hari (sejauh ini)
     */
    public function getAverageDailySpentAttribute()
    {
        $daysPassed = Carbon::now()->day;

        if ($daysPassed > 0 && $this->total_spent > 0) {
            return round($this->total_spent / $daysPassed, 2);
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
     * Scope: Filter budget bulan ini
     */
    public function scopeCurrentMonth($query)
    {
        return $query->where('month', now()->month)
            ->where('year', now()->year);
    }

    /**
     * Scope: Filter budget berdasarkan bulan & tahun spesifik
     */
    public function scopeForMonth($query, $month, $year)
    {
        return $query->where('month', $month)
            ->where('year', $year);
    }

    /**
     * Scope: Filter budget untuk user tertentu
     */
    public function scopeForUser($query, $userId)
    {
        return $query->where('user_id', $userId);
    }
}
