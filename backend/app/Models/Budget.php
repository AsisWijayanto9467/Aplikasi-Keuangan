<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Budget extends Model
{
    protected $table = "budgets";

    protected $fillable = [
        "user_id",
        "category_id",
        "limit_amount",
        "month",
        "year"
    ];

    public function user() {
        return $this->belongsTo(User::class);
    }

    public function category() {
        return $this->belongsTo(Category::class);
    }
}
