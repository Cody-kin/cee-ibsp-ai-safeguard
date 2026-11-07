'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ShieldCheck, UserPlus, LogIn } from 'lucide-react';

export default function LoginPage() {
  const [isLogin, setIsLogin] = useState(true);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const router = useRouter();

  const handleSubmit = async (e: any) => {
    // 🔥 就是這一行！攔截表單的預設重整行為，終結 404 閃退！
    e.preventDefault(); 
    setErrorMsg('');

    if (isLogin) {
      // 🟢 登入邏輯
      const formData = new URLSearchParams();
      formData.append('username', username);
      formData.append('password', password);

      try {
        const res = await fetch('/api/v1/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: formData.toString()
        });
        const data = await res.json();
        if (res.ok) {
          localStorage.setItem('aegis_token', data.access_token);
          localStorage.setItem('token', data.access_token);
          router.push('/');
        } else {
          // 💡 精準解開 JSON，拒絕 [object Object]
          const msg = data.detail || '請檢查帳號與密碼';
          setErrorMsg(msg);
          alert(`登入失敗: ${msg}`);
        }
      } catch (err: any) {
         alert(`網路錯誤: 伺服器沒有回應`);
      }
    } else {
      // 🔵 註冊邏輯 (對接 backend/app/main.py:101 的路由)
      try {
        const res = await fetch('/api/v1/auth/register', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password })
        });
        const data = await res.json();
        if (res.ok) {
          alert('✅ 註冊成功！請直接登入系統。');
          setIsLogin(true); // 註冊完自動切回登入
        } else {
          // 💡 精準解開 JSON，拒絕 [object Object]
          const msg = data.detail || JSON.stringify(data);
          setErrorMsg(msg);
          alert(`註冊失敗: ${msg}`);
        }
      } catch (err: any) {
         alert(`網路錯誤: 伺服器沒有回應`);
      }
    }
  };

  return (
    <div className="min-h-screen bg-[#0B0F19] flex items-center justify-center px-4 relative overflow-hidden">
      <div className="absolute top-[-10%] left-[-10%] w-96 h-96 bg-indigo-500/20 rounded-full blur-[100px]"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-96 h-96 bg-emerald-500/10 rounded-full blur-[100px]"></div>

      <div className="bg-[#131B2C] border border-[#1E293B] p-8 rounded-2xl shadow-2xl w-full max-w-md relative z-10">
        <div className="flex justify-center mb-6">
          <div className="p-4 bg-indigo-500/10 border border-indigo-500/20 rounded-full">
            <ShieldCheck className="w-12 h-12 text-indigo-400" />
          </div>
        </div>
        <h2 className="text-3xl font-black text-white text-center mb-2 tracking-wide">
          AI-SafeGuard
        </h2>
        <p className="text-gray-400 text-center mb-8 font-medium">
          {isLogin ? '安全登入系統' : '註冊新管理員帳號'}
        </p>

        {errorMsg && (
          <div className="bg-rose-500/10 border border-rose-500/20 text-rose-400 px-4 py-3 rounded-xl mb-6 text-sm font-bold text-center">
            {errorMsg}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-xs font-bold text-gray-500 uppercase tracking-widest mb-2">Username</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full bg-[#0B0F19] border border-[#2A3750] text-white px-4 py-3 rounded-xl focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all"
              placeholder="請輸入帳號"
              required
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-gray-500 uppercase tracking-widest mb-2">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-[#0B0F19] border border-[#2A3750] text-white px-4 py-3 rounded-xl focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all"
              placeholder="請輸入密碼"
              required
            />
          </div>

          <button type="submit" className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-3.5 rounded-xl transition-all shadow-lg shadow-indigo-500/25 flex justify-center items-center mt-4">
            {isLogin ? <><LogIn className="w-5 h-5 mr-2" /> 登入系統</> : <><UserPlus className="w-5 h-5 mr-2" /> 註冊帳號</>}
          </button>
        </form>

        <div className="mt-8 text-center">
          <button
            onClick={() => { setIsLogin(!isLogin); setErrorMsg(''); }}
            className="text-gray-400 hover:text-indigo-400 text-sm font-medium transition-colors"
          >
            {isLogin ? '沒有帳號嗎？點擊註冊' : '已有帳號？返回登入'}
          </button>
        </div>
      </div>
    </div>
  );
}
