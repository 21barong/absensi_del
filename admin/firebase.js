import { initializeApp } from "https://www.gstatic.com/firebasejs/10.11.0/firebase-app.js";
import {
  getAuth,
  signInWithEmailAndPassword
} from "https://www.gstatic.com/firebasejs/10.11.0/firebase-auth.js";
import {
  getFirestore,
  collection,
  getDocs,
  query,
  where,
  orderBy,
  addDoc,
  deleteDoc,
  updateDoc,
  doc
} from "https://www.gstatic.com/firebasejs/10.11.0/firebase-firestore.js";

// ✅ Perbaiki konfigurasi firebase (cek kembali authDomain dan storageBucket)
const firebaseConfig = {
  apiKey: "AIzaSyARyvqlzLQIIvOpiTdHyisxIuEoO24qYbs",
  authDomain: "absensi-del.firebaseapp.com", // pastikan ini sama dengan di console.firebase.google.com
  projectId: "absensi-del",
  storageBucket: "absensi-del.appspot.com", // ✅ diperbaiki (harus pakai .appspot.com)
  messagingSenderId: "586457273274",
  appId: "1:586457273274:web:e8528908675393dbb10383",
  measurementId: "G-EQV2YKR7CE"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// ✅ Fungsi login (tambahkan pengecekan error)
async function loginWithEmail(email, password) {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    return userCredential.user;
  } catch (error) {
    console.error("Login failed:", error.message);
    throw error;
  }
}

// ✅ Ambil absensi berdasarkan NIM
async function getAttendanceByNim(nim) {
  if (!nim) return [];

  const attendanceRef = collection(db, 'attendance');
  const q = query(attendanceRef, where('nim', '==', nim), orderBy('timestamp', 'desc'));

  const querySnapshot = await getDocs(q);
  const results = [];
  querySnapshot.forEach((doc) => {
    results.push({ id: doc.id, ...doc.data() });
  });
  return results;
}

// ✅ Ambil data semua mahasiswa
async function getStudents() {
  const studentsRef = collection(db, "students");
  const q = query(studentsRef, orderBy("registration_date", "desc"));
  
  const snapshot = await getDocs(q);
  const students = [];
  snapshot.forEach(doc => {
    students.push({ id: doc.id, ...doc.data() });
  });
  return students;
}

// ✅ Ambil semua data absensi
async function getAllAttendance() {
  const attendanceRef = collection(db, "attendance");
  const snapshot = await getDocs(attendanceRef);

  const logs = [];
  snapshot.forEach(doc => {
    logs.push({ id: doc.id, ...doc.data() });
  });
  return logs;
}

export {
  auth,
  signInWithEmailAndPassword,
  loginWithEmail, // fungsi tambahan yang aman
  db,
  collection,
  getDocs,
  addDoc,
  deleteDoc,
  updateDoc,
  doc,
  query,
  orderBy,
  where,
  getStudents,
  getAttendanceByNim,
  getAllAttendance
};
