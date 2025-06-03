// attendance.js
import { getStudents, getAttendanceByNim } from './firebase.js';

let table;

window.onload = async () => {
  const students = await getStudents();
  const allAttendance = [];

  const studentMap = {};
  const studentSelect = document.getElementById("filterStudent");

  for (const student of students) {
    studentMap[student.nim] = student;
    const option = document.createElement("option");
    option.value = student.nim;
    option.textContent = student.name;
    studentSelect.appendChild(option);
  }

  for (const student of students) {
    const logs = await getAttendanceByNim(student.nim);
    logs.forEach(log => {
      allAttendance.push({
        nim: student.nim,
        name: student.name,
        program: student.program || "Unknown",
        type: log.type,
        timestamp: log.timestamp.toDate()
      });
    });
  }

  // Render table
  renderTable(allAttendance);

  // Filters
  document.getElementById("filterDate").addEventListener("change", () => {
    table.draw();
  });

  document.getElementById("filterStudent").addEventListener("change", () => {
    table.draw();
  });

  document.getElementById("resetBtn").addEventListener("click", () => {
    document.getElementById("filterDate").value = '';
    document.getElementById("filterStudent").value = 'all';
    table.draw();
  });
};

function renderTable(data) {
  const tbody = document.getElementById("attendanceBody");
  data.forEach((row, idx) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${row.nim}</td>
      <td>${row.name}</td>
      <td>${row.program}</td>
      <td>${row.type}</td>
      <td>${row.timestamp.toLocaleString()}</td>
      <td><button class="btn btn-sm btn-outline-danger">Delete</button></td>
    `;
    tbody.appendChild(tr);
  });

  table = new DataTable('#attendanceTable', {
    order: [[4, 'desc']],
    columnDefs: [
      { targets: 5, orderable: false }
    ]
  });

  $.fn.dataTable.ext.search.push((settings, rowData, dataIndex) => {
    const dateFilter = document.getElementById("filterDate").value;
    const studentFilter = document.getElementById("filterStudent").value;

    const rowDate = new Date(rowData[4]).toISOString().slice(0, 10);
    const rowNim = rowData[0];

    const dateMatch = !dateFilter || rowDate === dateFilter;
    const studentMatch = studentFilter === 'all' || rowNim === studentFilter;

    return dateMatch && studentMatch;
  });
}
