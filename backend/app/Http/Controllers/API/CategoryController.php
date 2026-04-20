<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        try {
            $query = Category::query();

            // 🔍 Filter berdasarkan type (income / expense)
            if ($request->has('type')) {
                $query->where('type', $request->type);
            }

            $categories = $query->latest()->get();

            return response()->json([
                'message' => 'List kategori',
                'data' => $categories
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                'message' => 'Server Error',
                'errors' => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        //
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        try {
            $request->validate([
                'name' => 'required|string|max:255',
                'type' => 'required|in:income,expense'
            ]);

            $category = Category::create([
                'name' => $request->name,
                'type' => $request->type
            ]);

            return response()->json([
                'message' => 'Kategori berhasil dibuat',
                'data' => $category
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                'message' => 'Server Error',
                'errors' => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        try {
            $category = Category::find($id);

            if (!$category) {
                return response()->json([
                    'message' => 'Kategori tidak ditemukan'
                ], 404);
            }

            return response()->json([
                'message' => 'Detail kategori',
                'data' => $category
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                'message' => 'Server Error',
                'errors' => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        try {
            $request->validate([
                'name' => 'required|string|max:255',
                'type' => 'required|in:income,expense'
            ]);

            $category = Category::find($id);

            if (!$category) {
                return response()->json([
                    'message' => 'Kategori tidak ditemukan'
                ], 404);
            }

            $category->update([
                'name' => $request->name,
                'type' => $request->type
            ]);

            return response()->json([
                'message' => 'Kategori berhasil diupdate',
                'data' => $category
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                'message' => 'Server Error',
                'errors' => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        try {
            $category = Category::find($id);

            if (!$category) {
                return response()->json([
                    'message' => 'Kategori tidak ditemukan'
                ], 404);
            }

            $category->delete();

            return response()->json([
                'message' => 'Kategori berhasil dihapus'
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                'message' => 'Server Error',
                'errors' => $th->getMessage()
            ], 500);
        }
    }
}
