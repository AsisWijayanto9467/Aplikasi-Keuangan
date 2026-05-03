<?php

namespace App\Services;

use App\Models\Balance;
use App\Models\Transaction;
use App\Models\Budget;
use App\Models\MonthlyIncome;
use App\Models\FinancialTarget;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ChatBotService
{
    protected string $apiKey;
    protected string $baseUrl;

    protected string $systemContext = "Anda adalah AI Assistant untuk aplikasi keuangan 'FinansialKu'.
        Tugas Anda adalah membantu pengguna dengan pertanyaan seputar saldo, transaksi, pemasukan, pengeluaran, budget, dan target keuangan.
        Jawablah selalu dalam Bahasa Indonesia dengan nada profesional, ramah, dan edukatif.
        Jika pengguna bertanya tentang data yang tidak tersedia di konteks, katakan dengan jujur bahwa Anda tidak memiliki data tersebut.
        Jangan pernah memberikan saran investasi ilegal atau rekomendasi yang berisiko tinggi.
        Selalu dorong pengguna untuk menabung dan mengelola keuangan dengan bijak.";

    public function __construct()
    {
        $this->apiKey = config('services.gemini.api_key');
        $this->baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';
    }

    /**
     * Generate greeting message with user's name
     * TIDAK menggunakan AI - langsung generate dari server
     */
    public function getGreeting(int $userId): array
    {
        $user = User::find($userId);

        if (!$user) {
            return [
                'greeting' => 'Selamat datang di FinansialKu! 👋',
                'quick_info' => null
            ];
        }

        $userName = $user->name;

        // Ambil waktu sekarang untuk greeting yang sesuai
        $hour = Carbon::now()->hour;
        if ($hour >= 5 && $hour < 12) {
            $timeGreeting = "Selamat pagi";
        } elseif ($hour >= 12 && $hour < 15) {
            $timeGreeting = "Selamat siang";
        } elseif ($hour >= 15 && $hour < 18) {
            $timeGreeting = "Selamat sore";
        } else {
            $timeGreeting = "Selamat malam";
        }

        // Ambil data ringkas untuk ditampilkan
        $balance = Balance::where('user_id', $userId)->first();
        $currentBalance = $balance ? $balance->balance : 0;

        $currentMonth = Carbon::now()->month;
        $currentYear = Carbon::now()->year;

        $totalExpense = Transaction::where('user_id', $userId)
            ->where('type', 'expense')
            ->whereMonth('date', $currentMonth)
            ->whereYear('date', $currentYear)
            ->sum('amount');

        $greetingMessage = "{$timeGreeting}, {$userName}! 👋\n\n";
        $greetingMessage .= "Saya asisten keuangan FinansialKu, siap membantu Anda mengelola keuangan dengan lebih baik.\n\n";

        // Tambahkan ringkasan keuangan
        if ($currentBalance > 0 || $totalExpense > 0) {
            $greetingMessage .= "📊 **Ringkasan Keuangan Anda:**\n";
            $greetingMessage .= "💰 Saldo: Rp " . number_format($currentBalance, 0, ',', '.') . "\n";
            $greetingMessage .= "💸 Pengeluaran bulan ini: Rp " . number_format($totalExpense, 0, ',', '.') . "\n\n";
        }

        $greetingMessage .= "Apa yang bisa saya bantu hari ini? Anda bisa bertanya tentang:\n";
        $greetingMessage .= "• Saldo dan transaksi terbaru\n";
        $greetingMessage .= "• Budget dan pengeluaran\n";
        $greetingMessage .= "• Target keuangan Anda\n";
        $greetingMessage .= "• Tips mengelola keuangan";

        return [
            'greeting' => $greetingMessage,
            'quick_info' => [
                'balance' => $currentBalance,
                'monthly_expense' => $totalExpense,
                'user_name' => $userName
            ]
        ];
    }

    // Method sendMessage yang sudah dimodifikasi
    public function sendMessage(string $userMessage, int $userId, string $userName = null): string
    {
        // Jika user name tidak diberikan, ambil dari database
        if (!$userName) {
            $user = User::find($userId);
            $userName = $user ? $user->name : 'Pengguna';
        }

        // Deteksi topik pertanyaan untuk ambil data yang relevan saja
        $financialData = $this->gatherFinancialData($userId, $userMessage);

        $fullPrompt = $this->buildPrompt($financialData, $userMessage, $userName);

        $payload = [
            'contents' => [
                [
                    'parts' => [
                        ['text' => $fullPrompt]
                    ]
                ]
            ],
            'generationConfig' => [
                'temperature' => 0.3,
                'maxOutputTokens' => 1000,
                'topP' => 0.95,
            ]
        ];

        $response = Http::withHeaders([
            'Content-Type' => 'application/json',
            'X-goog-api-key' => $this->apiKey,
        ])->post($this->baseUrl, $payload);

        if ($response->successful()) {
            $data = $response->json();
            $reply = $data['candidates'][0]['content']['parts'][0]['text']
                ?? 'Maaf, saya tidak dapat menghasilkan jawaban saat ini.';

            // Pastikan AI menyapa dengan nama jika belum ada
            if (stripos($userMessage, 'halo') !== false ||
                stripos($userMessage, 'hai') !== false ||
                stripos($userMessage, 'hello') !== false) {
                // Cek apakah AI sudah menyebut nama
                if (stripos($reply, $userName) === false) {
                    $reply = "Halo {$userName}! " . lcfirst($reply);
                }
            }

            return $reply;
        }

        Log::error('Gemini API Error', [
            'status' => $response->status(),
            'body' => $response->body()
        ]);

        return 'Maaf, terjadi kesalahan sistem. Silakan coba lagi nanti.';
    }

    /**
     * Deteksi topik pertanyaan untuk query data yang relevan.
     */
    private function detectTopics(string $message): array
    {
        $message = strtolower($message);
        $topics = [];

        if (preg_match('/(saldo|uangku|punya uang|rekening|tabungan)/', $message)) {
            $topics[] = 'balance';
        }
        if (preg_match('/(pengeluaran|keluar|expense|belanja|bayar|transaksi keluar)/', $message)) {
            $topics[] = 'expenses';
        }
        if (preg_match('/(pemasukan|masuk|income|gaji|dapat uang|transaksi masuk)/', $message)) {
            $topics[] = 'incomes';
        }
        if (preg_match('/(budget|anggaran|batas|limit|sisa budget)/', $message)) {
            $topics[] = 'budgets';
        }
        if (preg_match('/(target|nabung|tabung|goal|impian|rencana|financial)/', $message)) {
            $topics[] = 'targets';
        }
        if (preg_match('/(transaksi|riwayat|history|mutasi|terbaru)/', $message)) {
            $topics[] = 'transactions';
        }

        // Kalau tidak terdeteksi atau pertanyaan umum, ambil semua
        if (empty($topics)) {
            $topics = ['balance', 'expenses', 'incomes', 'budgets', 'targets', 'transactions'];
        }

        return $topics;
    }

    private function gatherFinancialData(int $userId, string $userMessage = ''): array
    {
        $now = Carbon::now();
        $currentMonth = $now->month;
        $currentYear = $now->year;

        // Deteksi topik untuk efisiensi
        $topics = $this->detectTopics($userMessage);

        $data = ['current_month' => $now->format('F Y')];

        // Saldo (selalu diambil karena fundamental)
        if (in_array('balance', $topics)) {
            $balance = Balance::where('user_id', $userId)->first();
            $data['balance'] = $balance ? $balance->balance : 0;
        }

        // Pengeluaran bulan ini
        if (in_array('expenses', $topics)) {
            $data['total_expense_this_month'] = Transaction::where('user_id', $userId)
                ->where('type', 'expense')
                ->whereMonth('date', $currentMonth)
                ->whereYear('date', $currentYear)
                ->sum('amount');
        }

        // Pemasukan bulan ini
        if (in_array('incomes', $topics)) {
            $monthlyIncome = MonthlyIncome::where('user_id', $userId)
                ->where('month', $currentMonth)
                ->where('year', $currentYear)
                ->first();
            $data['monthly_income_total'] = $monthlyIncome ? $monthlyIncome->total_income : 0;

            $data['total_income_this_month'] = Transaction::where('user_id', $userId)
                ->where('type', 'income')
                ->whereMonth('date', $currentMonth)
                ->whereYear('date', $currentYear)
                ->sum('amount');
        }

        // Transaksi terbaru
        if (in_array('transactions', $topics)) {
            $recentTransactions = Transaction::where('user_id', $userId)
                ->with('category:id,name')
                ->orderBy('date', 'desc')
                ->orderBy('id', 'desc')
                ->limit(5)
                ->get();
            $data['recent_transactions'] = $recentTransactions->toArray();
        }

        // Budget
        if (in_array('budgets', $topics)) {
            $budgets = Budget::where('user_id', $userId)
                ->where('month', $currentMonth)
                ->where('year', $currentYear)
                ->with('category:id,name')
                ->get();
            $data['budgets'] = $budgets->toArray();
        }

        // Target
        if (in_array('targets', $topics)) {
            $activeTargets = FinancialTarget::where('user_id', $userId)
                ->where('status', 'active')
                ->orderBy('target_date', 'asc')
                ->limit(3)
                ->get();
            $data['active_targets'] = $activeTargets->toArray();
        }

        return $data;
    }

    private function buildPrompt(array $data, string $userMessage, string $userName = 'Pengguna'): string
    {
        $prompt = $this->systemContext . "\n\n";
        $prompt .= "=== DATA KEUANGAN PENGGUNA ===\n";
        $prompt .= "Nama Pengguna: {$userName}\n"; // TAMBAHKAN NAMA USER KE PROMPT
        $prompt .= "Bulan: {$data['current_month']}\n";

        // Hanya tampilkan data yang tersedia
        if (isset($data['balance'])) {
            $prompt .= "Saldo saat ini: Rp " . number_format($data['balance'], 0, ',', '.') . "\n";
        }

        if (isset($data['monthly_income_total'])) {
            $prompt .= "Total pemasukan bulan ini: Rp " . number_format($data['monthly_income_total'], 0, ',', '.') . "\n";
        }

        if (isset($data['total_expense_this_month'])) {
            $prompt .= "Total pengeluaran bulan ini: Rp " . number_format($data['total_expense_this_month'], 0, ',', '.') . "\n";
        }

        // Sisa uang (kalau kedua data tersedia)
        if (isset($data['total_income_this_month']) && isset($data['total_expense_this_month'])) {
            $sisa = $data['total_income_this_month'] - $data['total_expense_this_month'];
            $prompt .= "Sisa uang bulan ini: Rp " . number_format($sisa, 0, ',', '.') . "\n";
        }

        $prompt .= "\n";

        // 5 Transaksi Terbaru
        if (!empty($data['recent_transactions'])) {
            $prompt .= "=== 5 TRANSAKSI TERBARU ===\n";
            foreach ($data['recent_transactions'] as $trx) {
                $tipe = $trx['type'] === 'income' ? 'MASUK' : 'KELUAR';
                $kategori = $trx['category']['name'] ?? 'Tanpa Kategori';
                $prompt .= "- [{$trx['date']}] {$tipe}: Rp " . number_format($trx['amount'], 0, ',', '.') . " ({$trx['title']}, Kategori: {$kategori})\n";
            }
            $prompt .= "\n";
        }

        // Budget
        if (!empty($data['budgets'])) {
            $prompt .= "=== BUDGET BULAN INI ===\n";
            foreach ($data['budgets'] as $budget) {
                $kategori = $budget['category']['name'] ?? 'Kategori';
                $terpakai = DB::table('budget_transactions')
                    ->where('user_id', $budget['user_id'])
                    ->where('category_id', $budget['category_id'])
                    ->whereMonth('date', Carbon::now()->month)
                    ->whereYear('date', Carbon::now()->year)
                    ->sum('amount');
                $persen = $budget['limit_amount'] > 0 ? round(($terpakai / $budget['limit_amount']) * 100) : 0;

                // Tambahkan peringatan kalau budget hampir habis
                $warning = $persen >= 80 ? " ⚠️ HAMPIR HABIS!" : "";
                $prompt .= "- {$kategori}: Rp " . number_format($terpakai, 0, ',', '.') . " / Rp " . number_format($budget['limit_amount'], 0, ',', '.') . " ({$persen}%){$warning}\n";
            }
            $prompt .= "\n";
        }

        // Target Keuangan
        if (!empty($data['active_targets'])) {
            $prompt .= "=== TARGET KEUANGAN AKTIF ===\n";
            foreach ($data['active_targets'] as $target) {
                $progress = $target['target_amount'] > 0 ? round(($target['current_amount'] / $target['target_amount']) * 100) : 0;
                $deadline = Carbon::parse($target['target_date'])->format('d M Y');
                $sisaHari = Carbon::now()->diffInDays(Carbon::parse($target['target_date']), false);
                $warning = $sisaHari < 30 && $progress < 80 ? " ⚠️ WAKTU SEDIKIT!" : "";
                $prompt .= "- {$target['title']}: Rp " . number_format($target['current_amount'], 0, ',', '.') . " / Rp " . number_format($target['target_amount'], 0, ',', '.') . " ({$progress}%, Deadline: {$deadline}, Sisa: {$sisaHari} hari){$warning}\n";
            }
            $prompt .= "\n";
        }

        $prompt .= "=== PERTANYAAN PENGGUNA ===\n";
        $prompt .= $userMessage . "\n\n";
        $prompt .= "Jawab pertanyaan {$userName} berdasarkan data keuangan di atas. ";
        $prompt .= "SAPA {$userName} DI AWAL JAWABAN JIKA RELEVAN. ";
        $prompt .= "Gunakan format yang mudah dibaca dengan poin-poin atau ringkasan. ";
        $prompt .= "Jika data tidak mencukupi untuk menjawab, jelaskan keterbatasan data yang Anda miliki. ";
        $prompt .= "Berikan tips keuangan yang relevan jika memungkinkan.";

        return $prompt;
    }
}
