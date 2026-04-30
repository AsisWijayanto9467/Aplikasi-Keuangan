<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('target_savings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('financial_target_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->decimal('amount', 12, 2);
            $table->date('saving_date');
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['financial_target_id', 'saving_date']);
            $table->index(['user_id', 'saving_date']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('target_savings');
    }
};
