<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Category extends Model
{
    protected $table = "categories";

    protected $fillable = [
        "name",
        "type"
    ];

    public function transactions()
    {
        return $this->hasMany(Transaction::class);
    }

    public function budgets() {
        return $this->hasMany(Budget::class);
    }

    public function scopeExpense($query)
    {
        return $query->where('type', 'expense');
    }

    /**
     * Scope: Filter hanya income categories
     */
    public function scopeIncome($query)
    {
        return $query->where('type', 'income');
    }
}
