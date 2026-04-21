<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request) {
        try {
            $request->validate([
                'email' => 'required|email',
                'password' => 'required'
            ]);

            $user = User::where('email', $request->email)->first();

            if (!$user || !Hash::check($request->password, $user->password)) {
                return response()->json([
                    'message' => 'Email atau password salah'
                ], 401);
            }

            $token = $user->createToken('auth_token')->plainTextToken;

            return response()->json([
                'message' => 'Login berhasil',
                'token' => $token,
                'has_pin' => $user->pin ? true : false
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function getUser(Request $request)
    {
        try {
            $user = $request->user();

            return response()->json([
                'message' => 'Data user berhasil diambil',
                'data' => $user
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function updateUser(Request $request)
    {
        try {
            $user = $request->user();

            $request->validate([
                'name' => 'sometimes|required',
                'email' => 'sometimes|required|email|unique:users,email,' . $user->id,
                'phone' => 'sometimes|required|unique:users,phone,' . $user->id,
                'gender' => 'sometimes|required|in:male,female',
                'birth_date' => 'sometimes|required|date',
                'password' => 'nullable|min:6|confirmed'
            ]);

            $data = $request->only([
                'name',
                'email',
                'phone',
                'gender',
                'birth_date'
            ]);

            // kalau password diisi → hash
            if ($request->filled('password')) {
                $data['password'] = Hash::make($request->password);
            }

            $user->update($data);

            return response()->json([
                'message' => 'Data user berhasil diupdate',
                'data' => $user
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function register(Request $request) {
        try {
            $request->validate([
                'name' => 'required',
                'email' => 'required|email|unique:users',
                'phone' => 'required|unique:users',
                'gender' => 'required|in:male,female',
                'birth_date' => 'required|date',
                'password' => 'required|min:6|confirmed',
            ]);

            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'phone' => $request->phone,
                'gender' => $request->gender,
                'birth_date' => $request->birth_date,
                'password' => Hash::make($request->password),
                'pin' => null
            ]);

            $token = $user->createToken('auth_token')->plainTextToken;

            return response()->json([
                'message' => 'Register berhasil',
                'token' => $token
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }


    public function logout(Request $request) {
        try {
            $request->user()->currentAccessToken()->delete();

            return response()->json([
                'message' => 'Logout berhasil'
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function setPin(Request $request) {
        try {
            $request->validate([
                'pin' => 'required|digits:6|confirmed'
            ]);

            $user = $request->user();

            if ($user->pin) {
                return response()->json([
                    'message' => 'PIN sudah dibuat'
                ], 400);
            }

            $user->update([
                'pin' => Hash::make($request->pin)
            ]);

            return response()->json([
                'message' => 'PIN berhasil dibuat'
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }


    public function verifyPin(Request $request) {
        try {
            $request->validate([
                'pin' => 'required|digits:6'
            ]);

            $user = $request->user();

            if (!Hash::check($request->pin, $user->pin)) {
                return response()->json([
                    'message' => 'PIN salah'
                ], 401);
            }

            return response()->json([
                'message' => 'PIN benar',
                'status' => 'authenticated',
                'verified' => true
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }
}
