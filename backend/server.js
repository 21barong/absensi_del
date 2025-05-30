const express = require('express');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs/promises'); // Untuk menghapus file sementara
const path = require('path');
require('dotenv').config();
const db = require('./db'); // Import koneksi database

const app = express();
const upload = multer({ dest: 'uploads/' }); // Folder untuk menyimpan file yang diupload

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const FACEPP_API_KEY = process.env.FACEPP_API_KEY;
const FACEPP_API_SECRET = process.env.FACEPP_API_SECRET;
const FACEPP_FACESET_TOKEN = process.env.FACEPP_FACESET_TOKEN; // Ambil dari .env

// --- Helper function untuk memanggil Face++ API ---
async function callFacePPDetection(imagePath) {
    try {
        const formData = new FormData();
        formData.append('api_key', FACEPP_API_KEY);
        formData.append('api_secret', FACEPP_API_SECRET);
        formData.append('image_file', fs.createReadStream(imagePath));

        const response = await axios.post('https://api-us.faceplusplus.com/facepp/v3/detect', formData, {
            headers: {
                ...formData.getHeaders(),
            },
        });
        return response.data;
    } catch (error) {
        console.error('Face++ Detect Error:', error.response ? error.response.data : error.message);
        throw new Error(error.response ? error.response.data.error_message : 'Failed to detect face');
    }
}

async function callFacePPHelper(endpoint, data) {
    try {
        const formData = new FormData();
        formData.append('api_key', FACEPP_API_KEY);
        formData.append('api_secret', FACEPP_API_SECRET);
        for (const key in data) {
            formData.append(key, data[key]);
        }

        const response = await axios.post(`https://api-us.faceplusplus.com/facepp/v3/${endpoint}`, formData, {
            headers: {
                ...formData.getHeaders(),
            },
        });
        return response.data;
    } catch (error) {
        console.error(`Face++ ${endpoint} Error:`, error.response ? error.response.data : error.message);
        throw new Error(error.response ? error.response.data.error_message : `Failed to call Face++ ${endpoint}`);
    }
}


// --- 1. Endpoint Registrasi Mahasiswa ---
app.post('/api/students/register', upload.single('image_file'), async (req, res) => {
    try {
        const { nim, fullName, programStudi, email, phoneNumber } = req.body;
        const imagePath = req.file ? req.file.path : null;

        if (!nim || !fullName || !imagePath) {
            return res.status(400).json({ message: 'NIM, Nama Lengkap, dan Gambar Wajah harus diisi.' });
        }

        // 1. Deteksi wajah dari gambar
        const detectResult = await callFacePPDetection(imagePath);
        if (!detectResult.faces || detectResult.faces.length === 0) {
            return res.status(400).json({ message: 'Tidak ada wajah terdeteksi dalam gambar.' });
        }
        const faceToken = detectResult.faces[0].face_token;

        // 2. Tambahkan wajah ke FaceSet dan Set User ID (NIM)
        await callFacePPHelper('faceset/addface', {
            faceset_token: FACEPP_FACESET_TOKEN,
            face_tokens: faceToken,
        });
        await callFacePPHelper('face/setuserid', {
            face_token: faceToken,
            user_id: nim, // Gunakan NIM sebagai user_id di Face++
        });

        // 3. Simpan data mahasiswa ke database MySQL
        const [result] = await db.execute(
            'INSERT INTO students (nim, full_name, program_studi, email, phone_number, face_token) VALUES (?, ?, ?, ?, ?, ?)',
            [nim, fullName, programStudi, email, phoneNumber, faceToken]
        );

        res.status(201).json({ message: 'Mahasiswa berhasil didaftarkan!', studentId: result.insertId });

    } catch (error) {
        console.error('Registration error:', error);
        if (error.message.includes('DUPLICATE_OUTER_ID') || error.message.includes('user_id has existed')) {
            res.status(409).json({ message: 'NIM atau wajah ini sudah terdaftar.', error: error.message });
        } else if (error.message.includes('Failed to detect face')) {
            res.status(400).json({ message: 'Gagal mendeteksi wajah dari gambar.', error: error.message });
        } else {
            res.status(500).json({ message: 'Terjadi kesalahan server.', error: error.message });
        }
    } finally {
        // Hapus file sementara setelah diproses
        if (req.file) {
            await fs.unlink(req.file.path);
        }
    }
});

// --- 2. Endpoint Scan Kehadiran (Masuk/Keluar) ---
app.post('/api/attendance/scan', upload.single('image_file'), async (req, res) => {
    try {
        const { scan_type } = req.body; // 'in' atau 'out'
        const imagePath = req.file ? req.file.path : null;

        if (!scan_type || !imagePath || !['in', 'out'].includes(scan_type)) {
            return res.status(400).json({ message: 'Tipe scan dan gambar wajah harus valid.' });
        }

        // 1. Deteksi wajah dari gambar
        const detectResult = await callFacePPDetection(imagePath);
        if (!detectResult.faces || detectResult.faces.length === 0) {
            return res.status(400).json({ message: 'Tidak ada wajah terdeteksi dalam gambar.' });
        }
        const faceToken = detectResult.faces[0].face_token;

        // 2. Cari wajah di FaceSet
        const searchResult = await callFacePPHelper('search', {
            face_token: faceToken,
            faceset_token: FACEPP_FACESET_TOKEN,
        });

        if (!searchResult.results || searchResult.results.length === 0 || searchResult.results[0].confidence < searchResult.thresholds['1e-5']) {
            return res.status(404).json({ message: 'Wajah tidak terdaftar atau tidak cocok.' });
        }

        const matchedNim = searchResult.results[0].user_id;

        // 3. Ambil data mahasiswa dari database
        const [students] = await db.execute('SELECT id, full_name FROM students WHERE nim = ?', [matchedNim]);
        if (students.length === 0) {
            return res.status(404).json({ message: 'NIM dari wajah yang cocok tidak ditemukan di database.' });
        }
        const studentId = students[0].id;
        const studentName = students[0].full_name;

        // 4. Catat absensi ke database
        await db.execute(
            'INSERT INTO attendance_records (student_id, timestamp, event_type) VALUES (?, ?, ?)',
            [studentId, new Date(), scan_type]
        );

        res.status(200).json({
            message: `${scan_type === 'in' ? 'Selamat datang' : 'Terima kasih'}, ${studentName}! Absensi ${scan_type} berhasil dicatat.`,
            studentName: studentName,
            nim: matchedNim,
            type: scan_type,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Attendance scan error:', error);
        res.status(500).json({ message: 'Terjadi kesalahan server.', error: error.message });
    } finally {
        if (req.file) {
            await fs.unlink(req.file.path);
        }
    }
});

// --- 3. Endpoint Status Kehadiran ---
app.get('/api/attendance/status', async (req, res) => {
    try {
        const nim = req.query.nim;

        if (!nim) {
            return res.status(400).json({ message: 'NIM harus disediakan.' });
        }

        const [students] = await db.execute('SELECT id, nim, full_name, program_studi FROM students WHERE nim = ?', [nim]);
        if (students.length === 0) {
            return res.status(404).json({ message: 'Mahasiswa dengan NIM tersebut tidak ditemukan.' });
        }

        const student = students[0];

        const [records] = await db.execute(
            'SELECT timestamp, event_type FROM attendance_records WHERE student_id = ? ORDER BY timestamp DESC',
            [student.id]
        );

        res.status(200).json({
            student: {
                nim: student.nim,
                fullName: student.full_name,
                programStudi: student.program_studi,
            },
            attendanceRecords: records.map(record => ({
                timestamp: record.timestamp,
                type: record.event_type,
            })),
        });

    } catch (error) {
        console.error('Status check error:', error);
        res.status(500).json({ message: 'Terjadi kesalahan server.', error: error.message });
    }
});

app.get('/api/faceset/get_token', (req, res) => {
    if (process.env.FACEPP_FACESET_TOKEN) {
        res.status(200).json({
            success: true,
            facesetToken: process.env.FACEPP_FACESET_TOKEN
        });
    } else {
        res.status(500).json({
            success: false,
            message: 'FACEPP_FACESET_TOKEN not set in .env'
        });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});