<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Balance;
use App\Models\Category;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class TransactionController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        try {
            $user = $request->user();

            $query = Transaction::with('category')
                ->where('user_id', $user->id);

            if ($request->has('type')) {
                $query->where('type', $request->type);
            }

            if ($request->has('category_id')) {
                $query->where('category_id', $request->category_id);
            }

            if ($request->has('start_date')) {
                $query->whereDate('date', '>=', $request->start_date);
            }
            if ($request->has('end_date')) {
                $query->whereDate('date', '<=', $request->end_date);
            }

            $query->orderBy('date', 'desc');
            $transactions = $query->paginate(10);

            return response()->json([
                'message' => 'Riwayat transaksi',
                'data' => $transactions
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function statistics(Request $request)
    {
        try {
            $user = $request->user();
            $period = $request->get('period', 'month');
            $year = $request->get('year', date('Y'));
            $month = $request->get('month', date('m'));

            $categoryStats = Transaction::with('category')
                ->where('user_id', $user->id)
                ->whereYear('date', $year)
                ->when($period == 'month', function ($query) use ($month) {
                    return $query->whereMonth('date', $month);
                })
                ->selectRaw('category_id, type, SUM(amount) as total_amount')
                ->groupBy('category_id', 'type')
                ->get();

            $expenseByCategory = [];
            $incomeByCategory = [];

            foreach ($categoryStats as $stat) {
                $categoryName = $stat->category->name ?? 'Lainnya';
                $categoryIcon = $stat->category->icon ?? '📊';
                $categoryColor = $stat->category->color ?? '#64748B';

                if ($stat->type == 'expense') {
                    $expenseByCategory[] = [
                        'category' => $categoryName,
                        'icon' => $categoryIcon,
                        'color' => $categoryColor,
                        'amount' => (float) $stat->total_amount
                    ];
                } else {
                    $incomeByCategory[] = [
                        'category' => $categoryName,
                        'icon' => $categoryIcon,
                        'color' => $categoryColor,
                        'amount' => (float) $stat->total_amount
                    ];
                }
            }

            // Query untuk bar chart (trend harian/bulanan)
            $trendData = [];

            if ($period == 'month') {
                // Data per hari dalam bulan ini
                $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
                for ($day = 1; $day <= $daysInMonth; $day++) {
                    $date = sprintf('%s-%s-%02d', $year, $month, $day);

                    $dailyIncome = Transaction::where('user_id', $user->id)
                        ->whereDate('date', $date)
                        ->where('type', 'income')
                        ->sum('amount');

                    $dailyExpense = Transaction::where('user_id', $user->id)
                        ->whereDate('date', $date)
                        ->where('type', 'expense')
                        ->sum('amount');

                    $trendData[] = [
                        'label' => (string) $day,
                        'income' => (float) $dailyIncome,
                        'expense' => (float) $dailyExpense
                    ];
                }
            } else {
                // Data per bulan dalam tahun ini
                for ($monthNum = 1; $monthNum <= 12; $monthNum++) {
                    $monthlyIncome = Transaction::where('user_id', $user->id)
                        ->whereYear('date', $year)
                        ->whereMonth('date', $monthNum)
                        ->where('type', 'income')
                        ->sum('amount');

                    $monthlyExpense = Transaction::where('user_id', $user->id)
                        ->whereYear('date', $year)
                        ->whereMonth('date', $monthNum)
                        ->where('type', 'expense')
                        ->sum('amount');

                    $monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

                    $trendData[] = [
                        'label' => $monthNames[$monthNum - 1],
                        'income' => (float) $monthlyIncome,
                        'expense' => (float) $monthlyExpense
                    ];
                }
            }

            // Total summary
            $totalIncome = Transaction::where('user_id', $user->id)
                ->whereYear('date', $year)
                ->when($period == 'month', function ($query) use ($month) {
                    return $query->whereMonth('date', $month);
                })
                ->where('type', 'income')
                ->sum('amount');

            $totalExpense = Transaction::where('user_id', $user->id)
                ->whereYear('date', $year)
                ->when($period == 'month', function ($query) use ($month) {
                    return $query->whereMonth('date', $month);
                })
                ->where('type', 'expense')
                ->sum('amount');

            // Persentase pengeluaran vs pemasukan
            $totalTransactions = $totalIncome + $totalExpense;
            $incomePercentage = $totalTransactions > 0 ? ($totalIncome / $totalTransactions) * 100 : 0;
            $expensePercentage = $totalTransactions > 0 ? ($totalExpense / $totalTransactions) * 100 : 0;

            return response()->json([
                'message' => 'Data statistik',
                'data' => [
                    'period' => $period,
                    'year' => (int) $year,
                    'month' => $period == 'month' ? (int) $month : null,
                    'summary' => [
                        'total_income' => (float) $totalIncome,
                        'total_expense' => (float) $totalExpense,
                        'net_cashflow' => (float) ($totalIncome - $totalExpense),
                        'income_percentage' => round($incomePercentage, 2),
                        'expense_percentage' => round($expensePercentage, 2)
                    ],
                    'expense_by_category' => $expenseByCategory,
                    'income_by_category' => $incomeByCategory,
                    'trend_data' => $trendData
                ]
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }
    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        try {
            //
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        try {
            $request->validate([
                'category_id' => 'required|exists:categories,id',
                'title' => 'required|string|max:255',
                'description' => 'nullable|string',
                'amount' => 'required|numeric|min:1',
                'payment_method' => 'required|in:cash,qris,transfer',
                'type' => 'required|in:income,expense',
                'date' => 'required|date'
            ]);

            $user = $request->user();

            $category = Category::find($request->category_id);

            if ($category->type !== $request->type) {
                return response()->json([
                    'message' => 'Tipe kategori tidak sesuai dengan transaksi'
                ], 400);
            }

            DB::transaction(function () use ($request, $user, &$transaction) {

                $transaction = Transaction::create([
                    'user_id' => $user->id,
                    'category_id' => $request->category_id,
                    'title' => $request->title,
                    'description' => $request->description,
                    'amount' => $request->amount,
                    'type' => $request->type,
                    'payment_method' => $request->payment_method,
                    'date' => $request->date,
                ]);

                $balance = Balance::firstOrCreate(
                    ['user_id' => $user->id],
                    ['balance' => 0, 'is_initialized' => true]
                );

                if ($request->type == 'expense' && $balance->balance < $request->amount) {
                    return response()->json([
                        'message' => 'Saldo tidak mencukupi'
                    ], 400);
                }

                if ($request->type == 'income') {
                    $balance->balance += $request->amount;
                } else {
                    $balance->balance -= $request->amount;
                }

                $balance->save();
            });

            return response()->json([
                'message' => 'Transaksi berhasil ditambahkan',
                'data' => $transaction
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id, Request $request)
    {
        try {
            $user = $request->user();

            // 🔍 Ambil transaksi milik user + relasi kategori
            $transaction = Transaction::with('category')
                ->where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            return response()->json([
                'message' => 'Detail transaksi',
                'data' => $transaction
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(string $id)
    {
        try {
            //
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        try {
            $request->validate([
                'category_id' => 'required|exists:categories,id',
                'title' => 'required|string|max:255',
                'description' => 'nullable|string',
                'amount' => 'required|numeric|min:1',
                'payment_method' => 'required|in:cash,qris,transfer',
                'type' => 'required|in:income,expense',
                'date' => 'required|date'
            ]);

            $user = $request->user();

            $transaction = Transaction::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            $category = Category::find($request->category_id);

            if ($category->type !== $request->type) {
                return response()->json([
                    'message' => 'Tipe kategori tidak sesuai'
                ], 400);
            }

            DB::transaction(function () use ($request, $transaction) {

                $balance = Balance::where('user_id', $transaction->user_id)->first();

                // 🔁 rollback transaksi lama
                if ($transaction->type == 'income') {
                    $balance->balance -= $transaction->amount;
                } else {
                    $balance->balance += $transaction->amount;
                }

                $transaction->update([
                    'category_id' => $request->category_id,
                    'title' => $request->title,
                    'description' => $request->description,
                    'amount' => $request->amount,
                    'type' => $request->type,
                    'payment_method' => $request->payment_method,
                    'date' => $request->date,
                ]);

                if ($request->type == 'income') {
                    $balance->balance += $request->amount;
                } else {
                    $balance->balance -= $request->amount;
                }

                $balance->save();
            });

            return response()->json([
                'message' => 'Transaksi berhasil diupdate',
                'data' => $transaction
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id, Request $request)
    {
        try {
            $user = $request->user();

            $transaction = Transaction::where('id', $id)
                ->where('user_id', $user->id)
                ->first();

            if (!$transaction) {
                return response()->json([
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            DB::transaction(function () use ($transaction) {

                $balance = Balance::where('user_id', $transaction->user_id)->first();

                if ($transaction->type == 'income') {
                    $balance->balance -= $transaction->amount;
                } else {
                    $balance->balance += $transaction->amount;
                }

                $balance->save();

                $transaction->delete();
            });

            return response()->json([
                'message' => 'Transaksi berhasil dihapus'
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                "message" => "Server Error",
                "errors" => $th->getMessage()
            ], 500);
        }
    }

    public function scanReceipt(Request $request)
    {
        try {
            $request->validate([
                'image' => 'required|image|mimes:jpeg,png,jpg|max:5120',
            ]);

            $user = $request->user();

            // 1. Simpan gambar sementara
            $image = $request->file('image');
            $imagePath = $image->store('receipts', 'public');
            $fullImagePath = storage_path('app/public/' . $imagePath);

            // 2. Convert gambar ke base64
            $imageData = base64_encode(file_get_contents($fullImagePath));
            $mimeType = $image->getMimeType();

            // 3. Kirim ke OpenRouter untuk ekstraksi
            $extractedData = $this->extractReceiptData($imageData, $mimeType);

            // 4. Hapus gambar sementara
            if (file_exists($fullImagePath)) {
                unlink($fullImagePath);
            }

            // 5. Cari kategori yang cocok
            $suggestedCategory = $this->findMatchingCategory(
                $extractedData['title'] ?? '',
                $extractedData['description'] ?? '',
                $extractedData['raw_text'] ?? ''
            );

            // 6. Format amount (pastikan integer)
            $amount = is_numeric($extractedData['amount'] ?? 0)
                ? (int) $extractedData['amount']
                : 0;

            // 7. Validasi dan format tanggal
            $date = $this->parseDate($extractedData['date'] ?? date('Y-m-d'));

            // 8. Validasi payment method
            $validPaymentMethods = ['cash', 'qris', 'transfer', 'debit', 'credit'];
            $paymentMethod = in_array(strtolower($extractedData['payment_method'] ?? 'cash'), $validPaymentMethods)
                ? strtolower($extractedData['payment_method'])
                : 'cash';

            return response()->json([
                'success' => true,
                'message' => 'Struk berhasil di-scan',
                'data' => [
                    'title' => $extractedData['title'] ?? 'Pembelian BBM',
                    'amount' => $amount,
                    'date' => $date,
                    'description' => $extractedData['description'] ?? 'Pembelian di Pertamina',
                    'payment_method' => $paymentMethod,
                    'suggested_category_id' => $suggestedCategory,
                    'type' => 'expense',
                    'raw_text' => $extractedData['raw_text'] ?? '',
                ]
            ]);
        } catch (\Throwable $th) {
            Log::error('Scan Receipt Error: ' . $th->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Gagal memproses struk',
                'errors' => $th->getMessage()
            ], 500);
        }
    }

    /**
     * Parse dan validasi tanggal
     */
    private function parseDate($dateString): string
    {
        try {
            if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateString)) {
                $carbon = \Carbon\Carbon::createFromFormat('Y-m-d', $dateString);
                if ($carbon && $carbon->year > 2000 && $carbon->year <= (int) date('Y')) {
                    return $carbon->format('Y-m-d');
                }
            }

            if (preg_match('/^(\d{2})\/(\d{2})\/(\d{4})$/', $dateString, $matches)) {
                $carbon = \Carbon\Carbon::createFromFormat('d/m/Y', $dateString);
                if ($carbon && $carbon->year > 2000) {
                    return $carbon->format('Y-m-d');
                }
            }

            $timestamp = strtotime($dateString);
            if ($timestamp !== false && date('Y', $timestamp) > 2000) {
                return date('Y-m-d', $timestamp);
            }
        } catch (\Exception $e) {
            Log::warning('Date parse error: ' . $e->getMessage());
        }

        // Fallback ke hari ini
        return date('Y-m-d');
    }

    /**
     * Ekstrak data dari gambar struk menggunakan AI Vision
     */
    private function extractReceiptData(string $imageData, string $mimeType): array
    {
        $apiKey = config('services.openrouter.api_key');
        $model = 'google/gemini-2.0-flash-lite-001';

        $prompt = "Anda adalah AI pembaca struk Indonesia. Ekstrak informasi berikut dan KEMBALIKAN HANYA JSON VALID (tanpa markdown, tanpa penjelasan):
        {
            \"title\": \"Judul transaksi (contoh: Pembelian BBM, Makan di Restoran, Belanja Bulanan)\",
            \"amount\": 250000 (nominal total, ANGKA SAJA tanpa Rp, titik, atau koma),
            \"date\": \"2021-10-27\" (format YYYY-MM-DD, konversi dari format apapun di struk),
            \"description\": \"Deskripsi singkat (nama toko/tempat, item utama)\",
            \"payment_method\": \"cash\" (harus salah satu: cash/qris/transfer/debit/credit),
            \"raw_text\": \"Salin SEMUA teks yang terlihat di struk\"
        }

        ATURAN PENTING:
        1. amount HARUS berupa angka integer, contoh: 250000 (bukan 250.000 atau Rp 250.000)
        2. date HARUS format YYYY-MM-DD, konversi dari format DD/MM/YYYY jika perlu
        3. payment_method HARUS lowercase: cash, qris, transfer, debit, atau credit
        4. Jika ada tulisan CASH/TUNAI = cash, QRIS = qris, TRANSFER = transfer
        5. KEMBALIKAN HANYA JSON, tanpa \`\`\`json atau markdown apapun";

        try {
            $response = \Illuminate\Support\Facades\Http::timeout(30)->withHeaders([
                'Content-Type' => 'application/json',
                'Authorization' => 'Bearer ' . $apiKey,
                'HTTP-Referer' => config('app.url', 'http://localhost:8000'),
                'X-Title' => 'FinansialKu Receipt Scanner',
            ])->post('https://openrouter.ai/api/v1/chat/completions', [
                'model' => $model,
                'messages' => [
                    [
                        'role' => 'user',
                        'content' => [
                            [
                                'type' => 'text',
                                'text' => $prompt
                            ],
                            [
                                'type' => 'image_url',
                                'image_url' => [
                                    'url' => "data:{$mimeType};base64,{$imageData}"
                                ]
                            ]
                        ]
                    ]
                ],
                'temperature' => 0.1,
                'max_tokens' => 500,
            ]);

            if ($response->successful()) {
                $data = $response->json();
                $content = $data['choices'][0]['message']['content'] ?? '';

                // Bersihkan JSON dari markdown
                $content = preg_replace('/```json\s*|\s*```/', '', $content);
                $content = trim($content);

                $extracted = json_decode($content, true);

                if (json_last_error() === JSON_ERROR_NONE && is_array($extracted)) {
                    // Validasi minimal data yang diperlukan
                    return [
                        'title' => $extracted['title'] ?? 'Transaksi',
                        'amount' => $extracted['amount'] ?? 0,
                        'date' => $extracted['date'] ?? date('Y-m-d'),
                        'description' => $extracted['description'] ?? '',
                        'payment_method' => $extracted['payment_method'] ?? 'cash',
                        'raw_text' => $extracted['raw_text'] ?? '',
                    ];
                }

                Log::warning('Failed to parse AI response as JSON', [
                    'content' => $content,
                    'json_error' => json_last_error_msg()
                ]);
            } else {
                Log::error('OpenRouter API error', [
                    'status' => $response->status(),
                    'body' => $response->body()
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Extract receipt error: ' . $e->getMessage());
        }

        // Default values jika gagal
        return [
            'title' => 'Transaksi',
            'amount' => 0,
            'date' => date('Y-m-d'),
            'description' => '',
            'payment_method' => 'cash',
            'raw_text' => '',
        ];
    }

    /**
     * Cari kategori yang cocok berdasarkan judul, deskripsi, dan raw text
     */
    private function findMatchingCategory(string $title, string $description = '', string $rawText = ''): ?string
    {
        // Gabungkan semua text untuk pencarian
        $fullText = strtolower($title . ' ' . $description . ' ' . $rawText);

        // Mapping keyword ke category name (sesuai seeder)
        $categoryKeywords = [
            // Makan
            'makan' => 'Makan',
            'restoran' => 'Makan',
            'cafe' => 'Makan',
            'kopi' => 'Makan',
            'minum' => 'Makan',
            'sarapan' => 'Makan',
            'siang' => 'Makan',
            'malam' => 'Makan',
            'food' => 'Makan',
            'mie' => 'Makan',
            'nasi' => 'Makan',
            'bakso' => 'Makan',
            'sate' => 'Makan',
            'ayam' => 'Makan',
            'gorengan' => 'Makan',

            // Transport
            'bensin' => 'Transport',
            'pertamina' => 'Transport',
            'pertamax' => 'Transport',
            'parkir' => 'Transport',
            'transport' => 'Transport',
            'gojek' => 'Transport',
            'grab' => 'Transport',
            'ojek' => 'Transport',
            'taxi' => 'Transport',
            'taksi' => 'Transport',
            'tol' => 'Transport',
            'bengkel' => 'Transport',

            // Belanja
            'belanja' => 'Belanja',
            'mall' => 'Belanja',
            'toko' => 'Belanja',
            'minimarket' => 'Belanja',
            'supermarket' => 'Belanja',
            'indomaret' => 'Belanja',
            'alfamart' => 'Belanja',

            // Tagihan
            'listrik' => 'Tagihan',
            'pln' => 'Tagihan',
            'air' => 'Tagihan',
            'pdam' => 'Tagihan',
            'pulsa' => 'Tagihan',
            'wifi' => 'Tagihan',
            'internet' => 'Tagihan',
            'telpon' => 'Tagihan',
            'bpjs' => 'Tagihan',

            // Hiburan
            'bioskop' => 'Hiburan',
            'cinema' => 'Hiburan',
            'game' => 'Hiburan',
            'netflix' => 'Hiburan',
            'spotify' => 'Hiburan',
            'musik' => 'Hiburan',
            'liburan' => 'Hiburan',
        ];

        // Cari keyword yang cocok
        foreach ($categoryKeywords as $keyword => $categoryName) {
            if (str_contains($fullText, $keyword)) {
                $category = Category::where('name', $categoryName)
                    ->where('type', 'expense')
                    ->first();

                if ($category) {
                    return (string) $category->id;
                }
            }
        }

        // Default: cari kategori "Belanja" sebagai fallback
        $defaultCategory = Category::where('name', 'Belanja')
            ->where('type', 'expense')
            ->first();

        return $defaultCategory ? (string) $defaultCategory->id : null;
    }
}
