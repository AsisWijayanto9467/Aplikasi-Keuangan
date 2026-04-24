<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;

class BudgetTransaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'amount',
        'description',
        'date'
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'date' => 'date',
    ];

    /**
     * Relationship: BudgetTransaction belongs to User
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Relationship: BudgetTransaction belongs to Category
     */
    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Relationship: BudgetTransaction belongs to Budget (virtual relationship)
     */
    public function budget()
    {
        return $this->belongsTo(Budget::class, 'category_id', 'category_id')
            ->where('user_id', $this->user_id)
            ->where('month', $this->date->month)
            ->where('year', $this->date->year);
    }

    /**
     * Accessor: Format amount ke Rupiah
     */
    public function getFormattedAmountAttribute()
    {
        return 'Rp ' . number_format($this->amount, 0, ',', '.');
    }

    /**
     * Accessor: Format tanggal ke Bahasa Indonesia
     */
    public function getFormattedDateAttribute()
    {
        Carbon::setLocale('id');
        return Carbon::parse($this->date)->translatedFormat('d F Y');
    }

    /**
     * Boot method: Validasi sebelum menyimpan transaksi
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($transaction) {
            // Cek apakah budget untuk kategori ini ada
            $budget = Budget::where('user_id', $transaction->user_id)
                ->where('category_id', $transaction->category_id)
                ->where('month', Carbon::parse($transaction->date)->month)
                ->where('year', Carbon::parse($transaction->date)->year)
                ->first();

            if (!$budget) {
                throw new \Exception(
                    '⚠️ Budget untuk kategori "' .
                    Category::find($transaction->category_id)->name .
                    '" belum di-set untuk ' .
                    Carbon::parse($transaction->date)->format('F Y')
                );
            }

            // Hitung total pengeluaran yang sudah ada
            $totalSpent = static::where('user_id', $transaction->user_id)
                ->where('category_id', $transaction->category_id)
                ->whereMonth('date', Carbon::parse($transaction->date)->month)
                ->whereYear('date', Carbon::parse($transaction->date)->year)
                ->sum('amount');

            $newTotal = $totalSpent + $transaction->amount;

            // Validasi tidak melebihi budget
            if ($newTotal > $budget->limit_amount) {
                $remaining = $budget->limit_amount - $totalSpent;
                throw new \Exception(
                    '⚠️ Transaksi GAGAL! Budget ' .
                    Category::find($transaction->category_id)->name .
                    ' tersisa Rp ' . number_format($remaining, 0, ',', '.') .
                    ' | Anda mencoba mengeluarkan Rp ' . number_format($transaction->amount, 0, ',', '.')
                );
            }
        });

        static::created(function ($transaction) {
            // Optional: Trigger notifikasi jika budget hampir habis
            $budget = Budget::where('user_id', $transaction->user_id)
                ->where('category_id', $transaction->category_id)
                ->where('month', $transaction->date->month)
                ->where('year', $transaction->date->year)
                ->first();

            if ($budget && $budget->usage_percentage >= 90) {
                // Bisa trigger event/notifikasi disini
                Log::warning('Budget ' . $budget->category->name . ' sudah mencapai ' . $budget->usage_percentage . '%');
            }
        });
    }

    /**
     * Scope: Transaksi bulan ini
     */
    public function scopeCurrentMonth($query)
    {
        return $query->whereMonth('date', now()->month)
            ->whereYear('date', now()->year);
    }

    /**
     * Scope: Transaksi tanggal tertentu
     */
    public function scopeForDate($query, $date)
    {
        return $query->whereDate('date', $date);
    }

    /**
     * Scope: Transaksi hari ini
     */
    public function scopeToday($query)
    {
        return $query->whereDate('date', now()->format('Y-m-d'));
    }

    /**
     * Scope: Transaksi minggu ini
     */
    public function scopeThisWeek($query)
    {
        return $query->whereBetween('date', [
            now()->startOfWeek()->format('Y-m-d'),
            now()->endOfWeek()->format('Y-m-d')
        ]);
    }

    /**
     * Scope: Transaksi berdasarkan kategori
     */
    public function scopeForCategory($query, $categoryId)
    {
        return $query->where('category_id', $categoryId);
    }

    /**
     * Scope: Transaksi berdasarkan bulan & tahun
     */
    public function scopeForMonth($query, $month, $year)
    {
        return $query->whereMonth('date', $month)
            ->whereYear('date', $year);
    }

    /**
     * Scope: Transaksi untuk user tertentu
     */
    public function scopeForUser($query, $userId)
    {
        return $query->where('user_id', $userId);
    }

    /**
     * Scope: Urutkan berdasarkan tanggal terbaru
     */
    public function scopeLatest($query)
    {
        return $query->orderBy('date', 'desc')
            ->orderBy('created_at', 'desc');
    }

    /**
     * Scope: Urutkan berdasarkan nominal terbesar
     */
    public function scopeLargest($query)
    {
        return $query->orderBy('amount', 'desc');
    }
}
