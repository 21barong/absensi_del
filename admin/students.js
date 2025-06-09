import {
  db,
  collection,
  getDocs,
  addDoc,
  deleteDoc,
  updateDoc,
  doc,
  query,
  orderBy,
} from './firebase.js';

const studentsRef = collection(db, 'students');
const form = document.getElementById('add-student-form');
const tbody = document.getElementById('student-table-body');

// Tambah data mahasiswa
form.onsubmit = async (e) => {
  e.preventDefault();

  const nim = document.getElementById('nim').value;
  const name = document.getElementById('name').value; // pastikan ada input name
  const prodi = document.getElementById('prodi').value; // ambil input prodi

  await addDoc(studentsRef, {
    nim,
    name,
    prodi,
    registration_date: new Date()
  });

  form.reset();
  loadStudents();
};

// Tampilkan semua data mahasiswa
async function loadStudents() {
  const q = query(studentsRef, orderBy('registration_date', 'desc'));
  const snapshot = await getDocs(q);

  tbody.innerHTML = '';

  snapshot.forEach(docSnap => {
    const student = docSnap.data();
    const tr = document.createElement('tr');

    tr.innerHTML = `
      <td>${student.nim}</td>
      <td>${student.name || '-'}</td>
      <td>${student.prodi || '-'}</td>
      <td>${new Date(student.registration_date.toDate()).toLocaleDateString()}</td>
      <td>
        <button class="btn btn-sm btn-danger" data-id="${docSnap.id}" onclick="deleteStudent('${docSnap.id}')">Delete</button>
      </td>
    `;

    tbody.appendChild(tr);
  });

  enableInlineEdit();
}

// Hapus data mahasiswa
window.deleteStudent = async (id) => {
  const studentDoc = doc(db, 'students', id);
  await deleteDoc(studentDoc);
  loadStudents();
};

// Edit langsung data (nama, prodi, dll)
function enableInlineEdit() {
  document.querySelectorAll('[contenteditable="true"]').forEach(cell => {
    cell.onblur = async () => {
      const id = cell.dataset.id;
      const field = cell.dataset.field;
      const value = cell.textContent;

      const studentDoc = doc(db, 'students', id);
      await updateDoc(studentDoc, {
        [field]: value
      });
    };
  });
}

// Load saat halaman dibuka
loadStudents();
