'use client';
import { useState, useEffect } from 'react';
import { UserPlus, UserMinus, Users } from 'lucide-react';
import toast from 'react-hot-toast';

export default function UserManagement({ token }: { token: string }) {
  const [users, setUsers] = useState<any[]>([]);
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRole, setNewRole] = useState('admin');

  const fetchUsers = async () => {
    try {
      const res = await fetch('/api/v1/users', { headers: { 'Authorization': `Bearer ${token}` } });
      if (res.ok) {
        const data = await res.json();
        setUsers(data.data || data || []);
      }
    } catch (err) {}
  };

  useEffect(() => { fetchUsers(); }, []);

  const handleAddUser = async (e: any) => {
    e.preventDefault(); // 🔥 攔截重整
    if (!newUsername || !newPassword) return alert('請填寫帳號與密碼');
    try {
      const res = await fetch('/api/v1/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ username: newUsername, password: newPassword, role: newRole })
      });
      const data = await res.json();
      if (res.ok) {
        toast.success('用戶新增成功！');
        setNewUsername(''); setNewPassword(''); setNewRole('admin');
        fetchUsers();
      } else {
        // 💡 精準解包，不再出現 object Object
        alert(`新增失敗: ${data.detail || JSON.stringify(data)}`);
      }
    } catch (err: any) {
      alert(`網路錯誤: 伺服器沒有回應`);
    }
  };

  const handleDeleteUser = async (id: number) => {
    if (!confirm('確定要刪除此用戶嗎？')) return;
    try {
      const res = await fetch(`/api/v1/users/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        toast.success('用戶已刪除！');
        fetchUsers();
      } else {
        const data = await res.json();
        alert(`刪除失敗: ${data.detail || JSON.stringify(data)}`);
      }
    } catch (err: any) {
      alert(`網路錯誤: 伺服器沒有回應`);
    }
  };

  return (
    <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.25rem] p-6 shadow-xl">
      <h2 className="text-xl font-bold text-white mb-6 flex items-center">
        <Users className="w-5 h-5 mr-3 text-emerald-400" /> 用戶與權限管理
      </h2>

      {/* 🌟 100% 還原你截圖上的表單輸入區 */}
      <form onSubmit={handleAddUser} className="bg-[#0B0F19] p-4 rounded-xl border border-[#1E293B] flex flex-col sm:flex-row gap-4 mb-8">
        <input 
          type="text" 
          placeholder="用戶名" 
          value={newUsername} 
          onChange={(e)=>setNewUsername(e.target.value)} 
          className="flex-[2] bg-[#131B2C] border border-[#2A3750] text-white px-4 py-2.5 rounded-lg focus:outline-none focus:border-emerald-500" 
        />
        <input 
          type="password" 
          placeholder="密碼" 
          value={newPassword} 
          onChange={(e)=>setNewPassword(e.target.value)} 
          className="flex-[2] bg-[#131B2C] border border-[#2A3750] text-white px-4 py-2.5 rounded-lg focus:outline-none focus:border-emerald-500" 
        />
        <select 
          value={newRole} 
          onChange={(e)=>setNewRole(e.target.value)} 
          className="flex-1 bg-[#131B2C] border border-[#2A3750] text-white px-4 py-2.5 rounded-lg focus:outline-none focus:border-emerald-500 cursor-pointer"
        >
          <option value="admin">ADMIN</option>
          <option value="user">USER</option>
        </select>
        <button type="submit" className="bg-emerald-600 hover:bg-emerald-500 text-white px-6 py-2.5 rounded-lg font-bold flex items-center justify-center transition-colors shadow-lg shadow-emerald-500/20">
          <UserPlus className="w-4 h-4 mr-2" /> 新增
        </button>
      </form>

      {/* 🌟 100% 還原你截圖上的資料表格 */}
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm text-gray-400">
          <thead className="bg-[#0B0F19] text-gray-300 font-bold border-b border-[#1E293B]">
            <tr>
              <th className="px-5 py-4 rounded-tl-lg">用戶名</th>
              <th className="px-5 py-4">Email</th>
              <th className="px-5 py-4">身分</th>
              <th className="px-5 py-4 text-right rounded-tr-lg">操作</th>
            </tr>
          </thead>
          <tbody>
            {users.map(u => (
              <tr key={u.id} className="border-b border-[#1E293B]/50 hover:bg-[#1E293B]/20 transition-colors">
                <td className="px-5 py-4 text-white font-bold">{u.username}</td>
                <td className="px-5 py-4">{u.email || ''}</td>
                <td className="px-5 py-4">
                  <span className={`px-2.5 py-1 rounded text-[10px] font-black tracking-widest ${u.role === 'admin' ? 'bg-indigo-500/20 text-indigo-400' : 'bg-slate-500/20 text-slate-400'}`}>
                    {u.role ? u.role.toUpperCase() : 'USER'}
                  </span>
                </td>
                <td className="px-5 py-4 text-right">
                  <button onClick={() => handleDeleteUser(u.id)} className="text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 p-2 rounded-lg transition-colors cursor-pointer">
                    <UserMinus className="w-5 h-5 inline-block" />
                  </button>
                </td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr><td colSpan={4} className="text-center py-8 text-gray-500">尚無用戶資料</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
