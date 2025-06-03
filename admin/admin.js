import { getStudents, getAllAttendance } from './firebase.js';

function isToday(date) {
  const today = new Date();
  return (
    date.getDate() === today.getDate() &&
    date.getMonth() === today.getMonth() &&
    date.getFullYear() === today.getFullYear()
  );
}

window.onload = async () => {
  const students = await getStudents();
  document.getElementById("total-students").textContent = students.length;

  const allLogs = await getAllAttendance(); // fungsi ini ambil semua log absensi dari semua NIM
  const todayLogs = allLogs.filter(log => isToday(log.timestamp.toDate()));

  const checkins = todayLogs.filter(log => log.type === "masuk").length;
  const checkouts = todayLogs.filter(log => log.type === "keluar").length;

  document.getElementById("checkins").textContent = checkins;
  document.getElementById("checkouts").textContent = checkouts;

  renderRecent(todayLogs);
  renderChart(allLogs);
};

function renderRecent(logs) {
  const container = document.getElementById("recent-attendance");
  container.innerHTML = '';

  const sorted = logs.sort((a, b) => b.timestamp.toDate() - a.timestamp.toDate());
  const recent = sorted.slice(0, 5);

  if (recent.length === 0) {
    container.innerHTML = '<li class="list-group-item">No recent attendance</li>';
    return;
  }

  for (const log of recent) {
    const li = document.createElement("li");
    li.className = "list-group-item";
    li.textContent = `${log.nim} - ${log.type} - ${log.timestamp.toDate().toLocaleTimeString()}`;
    container.appendChild(li);
  }
}

function renderChart(logs) {
  const counts = {};
  const now = new Date();
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(now.getDate() - i);
    const key = d.toISOString().slice(0, 10);
    counts[key] = { checkin: 0, checkout: 0 };
  }

  logs.forEach(log => {
    const ts = log.timestamp.toDate();
    const key = ts.toISOString().slice(0, 10);
    if (counts[key]) {
      if (log.type === "check-in") counts[key].checkin++;
      if (log.type === "check-out") counts[key].checkout++;
    }
  });

  const labels = Object.keys(counts);
  const checkinData = labels.map(k => counts[k].checkin);
  const checkoutData = labels.map(k => counts[k].checkout);

  new Chart(document.getElementById("attendanceChart").getContext('2d'), {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          label: "Check-ins",
          data: checkinData,
          backgroundColor: "rgba(54, 162, 235, 0.7)"
        },
        {
          label: "Check-outs",
          data: checkoutData,
          backgroundColor: "rgba(255, 99, 132, 0.7)"
        }
      ]
    },
    options: {
      responsive: true,
      scales: {
        x: { stacked: true },
        y: { stacked: true, beginAtZero: true }
      }
    }
  });
}
