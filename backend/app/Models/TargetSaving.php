<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TargetSaving extends Model
{
    protected $table = "target_savings";

    protected $fillable = [
        'financial_target_id',
        'user_id',
        'amount',
        'saving_date',
        'notes'
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'saving_date' => 'date'
    ];

    public function financialTarget()
    {
        return $this->belongsTo(FinancialTarget::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
