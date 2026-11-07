import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import toast from 'react-hot-toast';

interface AiState {
  report: string;
  isGenerating: boolean;
  chatHistory: { role: string, content: string }[];
  generateReport: (token: string) => Promise<void>;
  askQuestion: (token: string, question: string) => Promise<void>;
}

export const useAiStore = create<AiState>()(
  persist(
    (set, get) => ({
      report: '',
      isGenerating: false,
      chatHistory: [],
      
      // 🌟 背景執行生成報告
      generateReport: async (token: string) => {
        set({ isGenerating: true });
        // 發出 Mac 風格的載入通知
        const toastId = toast.loading('AI is analyzing data in background...', { position: 'top-right' });
        
        try {
          const res = await fetch('/api/v1/analysis/qwen-insight', { headers: { 'Authorization': `Bearer ${token}` } });
          const data = await res.json();
          set({ report: data.report, isGenerating: false, chatHistory: [] });
          
          // 成功通知，點擊可跳轉回 Analytics
          toast.success('AI Report Generation Complete!', { 
            id: toastId, 
            duration: 5000,
            icon: '✨',
            style: { cursor: 'pointer', background: '#0f172a', color: '#fff', border: '1px solid #1e293b' }
          });
        } catch (e) {
          set({ isGenerating: false });
          toast.error('Failed to generate report', { id: toastId });
        }
      },

      // 🌟 互動對話功能
      askQuestion: async (token: string, question: string) => {
        const { report, chatHistory } = get();
        set({ chatHistory: [...chatHistory, { role: 'user', content: question }] });
        
        try {
          const res = await fetch('/api/v1/analysis/chat', {
            method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({ question, context: report })
          });
          const data = await res.json();
          set({ chatHistory: [...get().chatHistory, { role: 'ai', content: data.answer }] });
        } catch (e) {
          toast.error('Chat failed');
        }
      }
    }),
    { name: 'aegis-ai-storage' } // 快取在 LocalStorage
  )
);
