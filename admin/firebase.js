import { initializeApp } from "https://www.gstatic.com/firebasejs/10.11.0/firebase-app.js";
import { getAuth, signInWithEmailAndPassword } from "https://www.gstatic.com/firebasejs/10.11.0/firebase-auth.js";
import {
  getFirestore,
  collection,
  getDocs,
  query,
  where,
  orderBy
} from "https://www.gstatic.com/firebasejs/10.11.0/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyARyvqlzLQIIvOpiTdHyisxIuEoO24qYbs",
  authDomain: "absensi-del.firebaseapp.com",
  projectId: "absensi-del",
  storageBucket: "absensi-del.firebasestorage.app",
  messagingSenderId: "586457273274",
  appId: "1:586457273274:web:e8528908675393dbb10383",
  measurementId: "G-EQV2YKR7CE"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// Ambil data absensi berdasarkan NIM (digunakan untuk student-specific view)
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

// Ambil semua data mahasiswa
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

// Ambil semua data absensi dari seluruh mahasiswa
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
  db,
  collection,
  getDocs,
  getStudents,
  getAttendanceByNim,
  getAllAttendance
};
