const jwt = require('jsonwebtoken');

// ใช้ middleware นี้กับ route ที่ต้องการให้ login ก่อนถึงจะเข้าถึงได้
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization; // รูปแบบ: "Bearer <token>"

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'No token provided. Please sign in' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (err) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
};

module.exports = authMiddleware;
