<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        User::create([
            'name' => 'User Demo',
            'email' => 'user@gmail.com',
            'phone' => '081234567890',
            'gender' => 'male',
            'birth_date' => '2000-01-01',
            'password' => Hash::make('password123'),
            'pin' => Hash::make('123456')
        ]);

        User::create([
            'name' => 'User Cewe',
            'email' => 'cewe@gmail.com',
            'phone' => '081234567891',
            'gender' => 'female',
            'birth_date' => '2001-02-02',
            'password' => Hash::make('password123'),
            'pin' => Hash::make('654321')
        ]);
    }
}
