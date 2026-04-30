<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

class FinancialTarget extends Model
{
    protected $table = "financial_targets";

    protected $fillable = [
        'user_id',
        'title',
        'category',
        'reason',
        'target_amount',
        'current_amount',
        'target_date',
        'status',
        'icon',
        'notes'
    ];

    protected $casts = [
        'target_amount' => 'decimal:2',
        'current_amount' => 'decimal:2',
        'target_date' => 'date'
    ];

    protected $appends = [
        'progress_percentage',
        'remaining_amount',
        'remaining_days',
        'is_completed',
        'is_overdue'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function savings()
    {
        return $this->hasMany(TargetSaving::class);
    }

    // Accessor untuk progress
    public function getProgressPercentageAttribute()
    {
        if ($this->target_amount <= 0) return 0;
        return min(100, round(($this->current_amount / $this->target_amount) * 100, 2));
    }

    public function getRemainingAmountAttribute()
    {
        return max(0, $this->target_amount - $this->current_amount);
    }

    public function getRemainingDaysAttribute()
    {
        return Carbon::now()->startOfDay()->diffInDays(Carbon::parse($this->target_date)->startOfDay(), false);
    }

    public function getIsCompletedAttribute()
    {
        return $this->current_amount >= $this->target_amount;
    }

    public function getIsOverdueAttribute()
    {
        return !$this->getIsCompletedAttribute() && Carbon::now()->gt(Carbon::parse($this->target_date));
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }
}
