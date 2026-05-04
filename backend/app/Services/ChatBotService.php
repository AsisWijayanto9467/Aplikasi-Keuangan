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
    protected string $model;

    protected string $systemContext = "Anda adalah AI Assistant untuk aplikasi keuangan 'FinansialKu'.
    Tugas Anda adalah membantu pengguna dengan:
    1. Pertanyaan tentang saldo, transaksi, pemasukan, pengeluaran, budget, dan target keuangan MEREKA (berdasarkan data yang disediakan).
    2. Pertanyaan edukasi finansial SEPUTAR: tips menabung, budgeting, investasi (reksadana, emas, saham), mengelola keuangan, perencanaan keuangan, dll.

    ATURAN PENTING:
    - Jawab selalu dalam Bahasa Indonesia dengan nada profesional, ramah, dan edukatif.
    - Jika ditanya tentang data pribadi (saldo, transaksi), jawab berdasarkan DATA YANG DISEDIAKAN.
    - Jika data tidak tersedia, JELASKAN bahwa data tersebut tidak ada, lalu TETAP berikan jawaban edukatif.
    - Untuk pertanyaan edukasi (tips investasi, cara menabung), jawab dengan PENJELASAN UMUM berdasarkan prinsip keuangan yang sehat.
    - JANGAN PERNAH berikan rekomendasi investasi spesifik (sebut nama produk), prediksi keuntungan, atau klaim 'pasti untung'.
    - Dorong pengguna untuk belajar lebih lanjut, diversifikasi, dan konsultasi dengan profesional keuangan.
    - Gunakan format yang mudah dibaca.";

    public function __construct()
    {
        // ✅ PAKAI OPENROUTER, BUKAN GEMINI
        $this->apiKey = config('services.openrouter.api_key');
        $this->baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
        $this->model = config('services.openrouter.model', 'google/gemini-2.0-flash-lite-001');
    }

    /**
     * Generate greeting message with user's name
     * TIDAK menggunakan AI - langsung generate dari server (HEMAT TOKEN)
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

    /**
     * Kirim pesan ke OpenRouter API
     */
    public function sendMessage(string $userMessage, int $userId, string $userName = null): string
    {
        if (!$userName) {
            $user = User::find($userId);
            $userName = $user ? $user->name : 'Pengguna';
        }

        $financialData = $this->gatherFinancialData($userId, $userMessage);
        $prompt = $this->buildCompactPrompt($financialData, $userMessage, $userName);

        Log::info('OpenRouter Request', [
            'model' => $this->model,
            'prompt_length' => strlen($prompt)
        ]);

        // ✅ FORMAT OPENAI-COMPATIBLE (OpenRouter)
        $payload = [
            'model' => $this->model,
            'messages' => [
                ['role' => 'system', 'content' => $this->systemContext],
                ['role' => 'user', 'content' => $prompt]
            ],
            'temperature' => 0.3,
            'max_tokens' => 600,
        ];

        $response = Http::withHeaders([
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer ' . $this->apiKey,
            'HTTP-Referer' => config('app.url', 'http://localhost:8000'),
            'X-Title' => 'FinansialKu',
        ])->post($this->baseUrl, $payload);

        if ($response->successful()) {
            $data = $response->json();

            // Log token usage (untuk monitoring)
            if (isset($data['usage'])) {
                Log::info('OpenRouter Usage', [
                    'prompt_tokens' => $data['usage']['prompt_tokens'] ?? 0,
                    'completion_tokens' => $data['usage']['completion_tokens'] ?? 0,
                    'total_tokens' => $data['usage']['total_tokens'] ?? 0,
                    'cost' => $data['usage']['cost'] ?? 0, // Harusnya $0
                ]);
            }

            $reply = $data['choices'][0]['message']['content']
                ?? 'Maaf, saya tidak dapat menghasilkan jawaban saat ini.';

            // Tambahkan nama user di awal jika pertanyaan sapaan
            if (preg_match('/(halo|hai|hello|hallo|hei|hi|pagi|siang|sore|malam)/i', $userMessage)) {
                if (stripos($reply, $userName) === false) {
                    $reply = "Halo {$userName}! " . lcfirst($reply);
                }
            }

            return $reply;
        }

        Log::error('OpenRouter API Error', [
            'status' => $response->status(),
            'body' => $response->body()
        ]);

        return 'Maaf, terjadi kesalahan sistem. Silakan coba lagi nanti.';
    }

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

        // ✅ TAMBAHKAN DETEKSI TOPIK EDUKASI
        if (preg_match('/(investasi|saham|reksadana|obligasi|deposito|cara|tips|saran|edukasi|belajar|jelaskan|apa itu|bagaimana|strategi|kelola|atur|hemat)/', $message)) {
            $topics[] = 'education';
        }

        // Kalau tidak terdeteksi, ambil data dasar + education agar AI tetap bisa menjawab
        if (empty($topics)) {
            $topics = ['balance', 'expenses', 'incomes', 'education'];
        }

        return $topics;
    }

    private function gatherFinancialData(int $userId, string $userMessage = ''): array
    {
        $now = Carbon::now();
        $currentMonth = $now->month;
        $currentYear = $now->year;
        $topics = $this->detectTopics($userMessage);
        $data = ['current_month' => $now->format('F Y')];

        // ✅ HANYA ambil data jika topiknya relevan
        $needFinancialData = array_intersect($topics, ['balance', 'expenses', 'incomes', 'transactions', 'budgets', 'targets']);

        if (!empty($needFinancialData) || in_array('education', $topics)) {
            if (in_array('balance', $topics)) {
                $balance = Balance::where('user_id', $userId)->first();
                $data['balance'] = $balance ? $balance->balance : 0;
            }

            if (in_array('expenses', $topics)) {
                $data['total_expense_this_month'] = Transaction::where('user_id', $userId)
                    ->where('type', 'expense')
                    ->whereMonth('date', $currentMonth)
                    ->whereYear('date', $currentYear)
                    ->sum('amount');
            }

            if (in_array('incomes', $topics)) {
                $monthlyIncome = MonthlyIncome::where('user_id', $userId)
                    ->where('month', $currentMonth)
                    ->where('year', $currentYear)
                    ->first();
                $data['monthly_income_total'] = $monthlyIncome ? $monthlyIncome->total_income : 0;
            }

            if (in_array('transactions', $topics)) {
                $data['recent_transactions'] = Transaction::where('user_id', $userId)
                    ->with('category:id,name')
                    ->orderBy('date', 'desc')
                    ->orderBy('id', 'desc')
                    ->limit(3)
                    ->get()
                    ->toArray();
            }

            if (in_array('budgets', $topics)) {
                $data['budgets'] = Budget::where('user_id', $userId)
                    ->where('month', $currentMonth)
                    ->where('year', $currentYear)
                    ->with('category:id,name')
                    ->get()
                    ->toArray();
            }

            if (in_array('targets', $topics)) {
                $data['active_targets'] = FinancialTarget::where('user_id', $userId)
                    ->where('status', 'active')
                    ->orderBy('target_date', 'asc')
                    ->limit(2)
                    ->get()
                    ->toArray();
            }
        }

        return $data;
    }

    /**
     * ✅ PROMPT RINGKAS (hemat token 5-10x)
     */
    private function buildCompactPrompt(array $data, string $userMessage, string $userName): string
    {
        $lines = [];
        $lines[] = "=== DATA {$userName} ===";

        // Hanya tampilkan data jika tersedia dan relevan
        $hasFinancialData = isset($data['balance']) || isset($data['total_expense_this_month']);

        if ($hasFinancialData) {
            if (isset($data['balance'])) {
                $lines[] = "💰 Saldo: Rp" . number_format($data['balance'], 0, ',', '.');
            }
            if (isset($data['total_expense_this_month'])) {
                $lines[] = "📤 Pengeluaran/bln: Rp" . number_format($data['total_expense_this_month'], 0, ',', '.');
            }
            if (isset($data['monthly_income_total']) && $data['monthly_income_total'] > 0) {
                $lines[] = "📥 Pemasukan/bln: Rp" . number_format($data['monthly_income_total'], 0, ',', '.');
            }
            if (isset($data['monthly_income_total']) && isset($data['total_expense_this_month'])) {
                $sisa = $data['monthly_income_total'] - $data['total_expense_this_month'];
                $lines[] = "💡 Sisa: Rp" . number_format($sisa, 0, ',', '.');
            }
        }

        // Transaksi terbaru (max 3)
        if (!empty($data['recent_transactions'])) {
            $lines[] = "\n📋 Transaksi terbaru:";
            foreach (array_slice($data['recent_transactions'], 0, 3) as $trx) {
                $tipe = $trx['type'] === 'income' ? '+' : '-';
                $kat = $trx['category']['name'] ?? '';
                $lines[] = "  {$tipe}Rp" . number_format($trx['amount'], 0, ',', '.') . " - {$trx['title']}" . ($kat ? " ({$kat})" : "");
            }
        }

        // Budget kritis (>80%)
        if (!empty($data['budgets'])) {
            $kritis = [];
            foreach ($data['budgets'] as $budget) {
                $terpakai = DB::table('budget_transactions')
                    ->where('user_id', $budget['user_id'])
                    ->where('category_id', $budget['category_id'])
                    ->whereMonth('date', Carbon::now()->month)
                    ->whereYear('date', Carbon::now()->year)
                    ->sum('amount');
                $persen = $budget['limit_amount'] > 0 ? round(($terpakai / $budget['limit_amount']) * 100) : 0;
                if ($persen >= 80) {
                    $kritis[] = ($budget['category']['name'] ?? '') . ": {$persen}%";
                }
            }
            if (!empty($kritis)) {
                $lines[] = "\n⚠️ Budget hampir habis:";
                foreach ($kritis as $k) {
                    $lines[] = "  • {$k}";
                }
            }
        }

        // Target aktif
        if (!empty($data['active_targets'])) {
            $lines[] = "\n🎯 Target aktif:";
            foreach ($data['active_targets'] as $target) {
                $progress = $target['target_amount'] > 0 ? round(($target['current_amount'] / $target['target_amount']) * 100) : 0;
                $lines[] = "  • {$target['title']}: {$progress}%";
            }
        }

        $lines[] = "\n📝 Pertanyaan: {$userMessage}";

        // ✅ INSTRUKSI YANG DIPERBAIKI
        if ($hasFinancialData) {
            $lines[] = "Jika pertanyaan tentang data pribadi, jawab berdasarkan DATA di atas. Jika data tidak ada, jelaskan lalu berikan jawaban edukatif.";
        } else {
            $lines[] = "Tidak ada data keuangan pengguna. Berikan jawaban EDUKATIF dan UMUM tentang topik yang ditanyakan.";
        }
        $lines[] = "Jawab dalam Bahasa Indonesia yang ramah dan informatif. JANGAN menolak pertanyaan, selalu berikan nilai edukasi.";

        return implode("\n", $lines);
    }
}
