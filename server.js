/**
 * AQ录制软件官网文件服务器 v4.1
 * Node.js + Express 后端 · 安全加固版
 */

const express = require('express');
const multer = require('multer');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const compression = require('compression');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = 'aq-recorder-jwt-secret-2026';
const TOKEN_EXPIRY = '24h';

/* 全局异常捕获 —— 防止未处理异常导致进程崩溃 */
process.on('uncaughtException', function (err) {
    console.error('[CRASH] 未捕获异常:', err.message);
    console.error(err.stack);
});
process.on('unhandledRejection', function (reason, promise) {
    console.error('[CRASH] 未处理的Promise拒绝:', reason);
});

/* 安全常量 */
const MAX_LOGIN_ATTEMPTS = 5;        // 最大失败次数
const LOCKOUT_MINUTES = 15;          // 锁定分钟数
const LOCKOUT_CLEANUP_INTERVAL = 10; // 清理过期记录间隔（分钟）
const MAX_BODY_SIZE = '1mb';         // 请求体大小限制
const MAX_USERNAME_LEN = 64;         // 用户名最大长度
const MAX_PASSWORD_LEN = 128;        // 密码最大长度

// 目录路径
const UPLOADS_DIR = path.join(__dirname, 'uploads');
const DATA_DIR = path.join(__dirname, 'data');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
const FILES_META_FILE = path.join(DATA_DIR, 'files_meta.json');

// 确保目录存在
[UPLOADS_DIR, DATA_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

/* 登录失败追踪（内存内，重启清零） */
const loginFailures = {}; // { ip: { count, firstAttempt, lockedUntil } }

/* 定期清理过期锁定 */
setInterval(function () {
    const now = Date.now();
    Object.keys(loginFailures).forEach(function (ip) {
        // 清理已过期的锁定条目
        if (loginFailures[ip].lockedUntil && loginFailures[ip].lockedUntil < now) {
            delete loginFailures[ip];
            return;
        }
        // 如果记录存在但很久没有尝试，清理老旧记录以节省内存（例如 24 小时）
        if (loginFailures[ip].firstAttempt && (now - loginFailures[ip].firstAttempt) > 24 * 60 * 60 * 1000) {
            delete loginFailures[ip];
        }
    });
}, LOCKOUT_CLEANUP_INTERVAL * 60 * 1000);

/* 获取客户端真实 IP */
function getClientIP(req) {
    const xff = req.headers['x-forwarded-for'];
    if (xff && typeof xff === 'string') {
        // X-Forwarded-For 可能包含多个IP (client, proxy1, proxy2)，取第一个为客户端真实 IP
        return xff.split(',')[0].trim();
    }
    // 兼容不同 Node 版本的属性
    return (req.connection && req.connection.remoteAddress) || (req.socket && req.socket.remoteAddress) || '127.0.0.1';
}

// ==================== 中间件 ====================
app.use(cors());
app.use(express.json({ limit: MAX_BODY_SIZE }));

/* Gzip 压缩 */
app.use(compression({
    level: 6,
    filter: function (req, res) {
        if (req.headers['x-no-compression']) return false;
        return compression.filter(req, res);
    }
}));

/* 安全响应头 */
app.use(function (req, res, next) {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('X-DNS-Prefetch-Control', 'off');
    res.removeHeader('X-Powered-By');
    next();
});

/* 管理后台登录页面（内联渲染，不暴露 admin.html 源码） */
app.get('/login', function (req, res) {
    res.sendFile(path.join(__dirname, 'login.html'));
});

/* 管理后台 —— 受 JWT Cookie 保护，未登录跳转 /login */
app.get('/admin.html', function (req, res) {
    const token = parseCookie(req, 'aq_token');
    if (!token) return res.redirect('/login');

    try {
        jwt.verify(token, JWT_SECRET);
        res.sendFile(path.join(__dirname, 'admin.html'));
    } catch (err) {
        return res.redirect('/login');
    }
});

/* 静态文件服务（带缓存） */
const CACHE_1YEAR = 365 * 24 * 60 * 60 * 1000;
app.use(express.static(path.join(__dirname, 'public'), {
    maxAge: CACHE_1YEAR,
    etag: true,
    lastModified: true
}));
app.use('/downloads', express.static(UPLOADS_DIR, {
    maxAge: CACHE_1YEAR,
    etag: true,
    lastModified: true
}));

/* Cookie 解析工具 */
function parseCookie(req, name) {
    const cookieHeader = req.headers.cookie || '';
    const match = cookieHeader.match(new RegExp('(?:^|;\\s*)' + name + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : null;
}

// ==================== 工具函数 ====================

function loadUsers() {
    try {
        const raw = fs.readFileSync(USERS_FILE, 'utf-8');
        const data = JSON.parse(raw);
        // 防止意外写入数组导致属性无法序列化
        if (Array.isArray(data)) return {};
        return data;
    } catch {
        return {};
    }
}

function saveUsers(users) {
    fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2), 'utf-8');
}

function loadFilesMeta() {
    try {
        const raw = fs.readFileSync(FILES_META_FILE, 'utf-8');
        const data = JSON.parse(raw);
        return Array.isArray(data) ? data : [];
    } catch {
        return [];
    }
}

function saveFilesMeta(meta) {
    fs.writeFileSync(FILES_META_FILE, JSON.stringify(meta, null, 2), 'utf-8');
}

// 初始化默认管理员账号
function initAdmin() {
    const users = loadUsers();
    if (!users.admin) {
        const hash = bcrypt.hashSync('admin123', 10);
        users.admin = { username: 'admin', password: hash, createdAt: new Date().toISOString() };
        saveUsers(users);
        console.log('[Init] 默认管理员账号已创建: admin / admin123');
    }
}

initAdmin();

// ==================== JWT 认证中间件 ====================

function authMiddleware(req, res, next) {
    // 优先使用 Authorization: Bearer <token>
    const authHeader = req.headers.authorization;
    let token = null;

    if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.split(' ')[1];
    } else {
        // 回退到 Cookie（用于浏览器直接访问 admin 页面等场景）
        token = parseCookie(req, 'aq_token');
    }

    if (!token) {
        return res.status(401).json({ success: false, message: '未提供认证令牌' });
    }
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(401).json({ success: false, message: '认证令牌无效或已过期' });
    }
}

// ==================== Multer 配置 ====================

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, UPLOADS_DIR);
    },
    filename: function (req, file, cb) {
        // 保留原始文件名（中文支持），并添加唯一前缀避免覆盖
        const originalName = Buffer.from(file.originalname, 'latin1').toString('utf8');
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, uniqueSuffix + '-' + originalName);
    }
});

const fileFilter = function (req, file, cb) {
    // 处理中文文件名：multer 会将非 ASCII 字符编码为 latin1，需还原为 utf8
    const originalName = Buffer.from(file.originalname, 'latin1').toString('utf8');
    const ext = path.extname(originalName).toLowerCase();
    if (ext === '.exe') {
        cb(null, true);
    } else {
        // 使用非错误方式拒绝文件，multer 会返回 400，如果需要可改为 cb(new Error(...))
        cb(new Error('仅支持 .exe 文件上传'));
    }
};

const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: { fileSize: 500 * 1024 * 1024 } // 500MB
});

// ==================== API 路由 ====================

// 管理员登录（防爆破 + 输入校验）
app.post('/api/login', function (req, res) {
    const ip = getClientIP(req);
    const now = Date.now();

    /* 检查是否被锁定 */
    const fail = loginFailures[ip];
    if (fail && fail.lockedUntil && fail.lockedUntil > now) {
        const remaining = Math.ceil((fail.lockedUntil - now) / 60000);
        return res.status(429).json({
            success: false,
            message: '登录尝试次数过多，请 ' + remaining + ' 分钟后再试'
        });
    }

    const { username, password } = req.body;

    /* 输入校验 */
    if (!username || !password) {
        return res.status(400).json({ success: false, message: '请输入用户名和密码' });
    }
    if (typeof username !== 'string' || typeof password !== 'string') {
        return res.status(400).json({ success: false, message: '输入格式不正确' });
    }
    if (username.length > MAX_USERNAME_LEN || password.length > MAX_PASSWORD_LEN) {
        return res.status(400).json({ success: false, message: '用户名或密码过长' });
    }

    const users = loadUsers();
    const user = users[username];

    if (!user || !bcrypt.compareSync(password, user.password)) {
        /* 记录失败 */
        if (!loginFailures[ip]) {
            loginFailures[ip] = { count: 1, firstAttempt: now };
        } else {
            loginFailures[ip].count += 1;
        }

        if (loginFailures[ip].count >= MAX_LOGIN_ATTEMPTS) {
            loginFailures[ip].lockedUntil = now + LOCKOUT_MINUTES * 60 * 1000;
            return res.status(429).json({
                success: false,
                message: '登录失败次数过多，账号已锁定 ' + LOCKOUT_MINUTES + ' 分钟'
            });
        }

        const remaining = MAX_LOGIN_ATTEMPTS - loginFailures[ip].count;
        return res.status(401).json({
            success: false,
            message: '用户名或密码错误，还剩 ' + remaining + ' 次尝试机会'
        });
    }

    /* 登录成功，清除失败记录 */
    delete loginFailures[ip];

    const token = jwt.sign({ username: user.username }, JWT_SECRET, { expiresIn: TOKEN_EXPIRY });

    // 设置 httpOnly Secure Cookie（服务端验证用）
    const maxAge = 24 * 60 * 60 * 1000; // 24h
    res.cookie('aq_token', token, {
        httpOnly: true,
        secure: false,
        sameSite: 'strict',
        maxAge: maxAge,
        path: '/'
    });

    return res.json({ success: true, message: '登录成功', token: token });
});

// 退出登录（清除 Cookie）
app.post('/api/logout', function (req, res) {
    res.clearCookie('aq_token', { path: '/' });
    return res.json({ success: true, message: '已退出登录' });
});

// 文件上传
app.post('/api/upload', authMiddleware, function (req, res) {
    upload.single('file')(req, res, function (err) {
        if (err instanceof multer.MulterError) {
            if (err.code === 'LIMIT_FILE_SIZE') {
                return res.status(413).json({ success: false, message: '文件大小超过限制（最大 500MB）' });
            }
            return res.status(400).json({ success: false, message: '上传错误: ' + err.message });
        }
        if (err) {
            return res.status(400).json({ success: false, message: err.message });
        }
        if (!req.file) {
            return res.status(400).json({ success: false, message: '请选择要上传的文件' });
        }

        const fileInfo = {
            filename: req.file.filename,
            originalname: Buffer.from(req.file.originalname, 'latin1').toString('utf8'),
            size: req.file.size,
            uploadTime: new Date().toISOString()
        };

        const meta = loadFilesMeta();
        meta.push(fileInfo);
        saveFilesMeta(meta);

        return res.json({ success: true, message: '上传成功', file: fileInfo });
    });
});

// 获取文件列表（公开API，供前端展示）
app.get('/api/files', function (req, res) {
    const meta = loadFilesMeta();
    // 同步检查文件是否真实存在
    const validFiles = meta.filter(function (f) {
        const filePath = path.join(UPLOADS_DIR, f.filename);
        if (!fs.existsSync(filePath)) {
            return false;
        }
        try {
            const stats = fs.statSync(filePath);
            f.size = stats.size;
            f.uploadTime = stats.mtime.toISOString();
            return true;
        } catch {
            return false;
        }
    });

    if (validFiles.length !== meta.length) {
        saveFilesMeta(validFiles);
    }

    return res.json({ success: true, files: validFiles });
});

// 删除文件
app.delete('/api/files/:filename', authMiddleware, function (req, res) {
    const filename = decodeURIComponent(req.params.filename);
    const meta = loadFilesMeta();
    const index = meta.findIndex(function (f) {
        return f.filename === filename;
    });

    if (index === -1) {
        return res.status(404).json({ success: false, message: '文件不存在' });
    }

    const filePath = path.join(UPLOADS_DIR, filename);
    try {
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
    } catch (err) {
        return res.status(500).json({ success: false, message: '删除文件失败: ' + err.message });
    }

    meta.splice(index, 1);
    saveFilesMeta(meta);

    return res.json({ success: true, message: '文件已删除' });
});

// Token 验证接口（前端用于检查登录状态）
app.get('/api/verify', authMiddleware, function (req, res) {
    return res.json({ success: true, username: req.user.username });
});

// ==================== 启动服务器 ====================

app.listen(PORT, '0.0.0.0', function () {
    console.log('========================================');
    console.log('  AQ录制软件官网文件服务器已启动');
    console.log('  地址: http://localhost:' + PORT);
    console.log('  QQ群: 632984162');
    console.log('  管理后台: http://localhost:' + PORT + '/admin.html');
    console.log('  官网首页: http://localhost:' + PORT);
    console.log('========================================');
});
