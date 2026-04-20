<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Balance extends Model
{
    protected $table = "balances";

    protected $fillable = [
        "user_id",
        "balance",
        "is_initialized"
    ];

    public function user() {
        return $this->belongsTo(User::class);
    }
}
