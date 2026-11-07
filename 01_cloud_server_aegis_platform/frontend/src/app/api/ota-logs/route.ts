export const dynamic = 'force-dynamic'; // 🌟 魔法指令：嚴禁 Next.js 快取這個 API
import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

const LOG_FILE = path.join('/tmp', 'ota_history.json');

export async function GET() {
  try {
    if (!fs.existsSync(LOG_FILE)) return NextResponse.json([]);
    const data = fs.readFileSync(LOG_FILE, 'utf-8');
    return NextResponse.json(JSON.parse(data));
  } catch (e) {
    return NextResponse.json([]);
  }
}

export async function POST(req: Request) {
  try {
    const body = await req.json();
    let logs: any[] = [];
    if (fs.existsSync(LOG_FILE)) {
      logs = JSON.parse(fs.readFileSync(LOG_FILE, 'utf-8'));
    }
    
    const newLog = {
      id: Date.now().toString(),
      timestamp: new Date().toLocaleString('zh-TW', { hour12: false }),
      status: body.status,
      message: body.message
    };
    
    logs.unshift(newLog); 
    logs = logs.slice(0, 100); 
    
    fs.writeFileSync(LOG_FILE, JSON.stringify(logs, null, 2));
    return NextResponse.json(newLog);
  } catch (e) {
    return NextResponse.json({ error: 'Failed to write log' }, { status: 500 });
  }
}

export async function DELETE() {
  try {
    if (fs.existsSync(LOG_FILE)) {
      fs.unlinkSync(LOG_FILE);
    }
    return NextResponse.json({ success: true });
  } catch (e) {
    return NextResponse.json({ error: 'Failed to delete' }, { status: 500 });
  }
}
