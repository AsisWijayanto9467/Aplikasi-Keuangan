<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Services\ChatBotService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ChatController extends Controller
{
    protected ChatBotService $chatChatBotService;

    public function __construct(ChatBotService $chatBotService)
    {
        $this->chatBotService = $chatBotService;
    }

    /**
     * Endpoint untuk mendapatkan greeting awal saat buka chatbot.
     * GET /api/chat/greeting
     */
    public function getGreeting()
    {
        $user = Auth::user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'reply' => 'Anda harus login terlebih dahulu untuk menggunakan chatbot.',
                'timestamp' => now()->toDateTimeString(),
            ], 401);
        }

        $greetingData = $this->chatBotService->getGreeting($user->id);

        return response()->json([
            'success' => true,
            'reply' => $greetingData['greeting'],
            'quick_info' => $greetingData['quick_info'],
            'timestamp' => now()->toDateTimeString(),
        ]);
    }

    /**
     * Endpoint untuk chatbot keuangan.
     * POST /api/chat/send
     */
    public function sendChat(Request $request)
    {
        $validated = $request->validate([
            'message' => 'required|string|max:500',
        ]);

        // Ambil user yang sedang login
        $user = Auth::user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'reply' => 'Anda harus login terlebih dahulu untuk menggunakan chatbot.',
                'timestamp' => now()->toDateTimeString(),
            ], 401);
        }

        // PASS USER NAME ke service
        $reply = $this->chatBotService->sendMessage(
            $validated['message'],
            $user->id,
            $user->name  // Tambahkan parameter nama user
        );

        return response()->json([
            'success' => true,
            'reply' => $reply,
            'timestamp' => now()->toDateTimeString(),
        ]);
    }
}
