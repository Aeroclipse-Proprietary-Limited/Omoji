/* ─── Modal ───────────────────────────────────── */

const modal   = document.getElementById("apply-modal");
const openBtn = document.getElementById("open-apply-modal");
const closeBtn = document.getElementById("close-apply-modal");

function openModal() {
  modal.classList.add("is-open");
  document.body.style.overflow = "hidden";
  closeBtn.focus();
}

function closeModal() {
  modal.classList.remove("is-open");
  document.body.style.overflow = "";
  openBtn.focus();
}

openBtn.addEventListener("click", openModal);
closeBtn.addEventListener("click", closeModal);

// Close on backdrop click
modal.addEventListener("click", (e) => {
  if (e.target === modal) closeModal();
});

// Close on Escape
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && modal.classList.contains("is-open")) closeModal();
});

/* ─── Career Form ─────────────────────────────── */

const careerForm = document.querySelector("#career-form");
const cvInput    = careerForm.elements.namedItem("cv");
const formStatus = document.querySelector("#form-status");

careerForm.addEventListener("submit", (event) => {
  event.preventDefault();
  cvInput.setCustomValidity("");

  const cv = cvInput.files[0];
  if (!cv) {
    cvInput.setCustomValidity("Choose your CV before preparing the email.");
    cvInput.reportValidity();
    return;
  }

  if (!/\.((pdf)|(doc)|(docx))$/i.test(cv.name)) {
    cvInput.setCustomValidity("Choose a PDF or Word document.");
    cvInput.reportValidity();
    return;
  }

  const fields  = new FormData(careerForm);
  const subject = "Aeroclipse career enquiry";
  const body = [
    "Hello Aeroclipse,",
    "",
    "I'd like to enquire about a career opportunity.",
    "",
    `Name: ${fields.get("name")}`,
    `Surname: ${fields.get("surname")}`,
    `Email: ${fields.get("email")}`,
    `CV to attach: ${cv.name}`,
    "",
    "I will attach my CV before sending this email.",
  ].join("\n");

  const query = new URLSearchParams({ subject, body });
  formStatus.textContent =
    "Opening your email app. Attach your CV before sending.";
  window.location.href = `mailto:godlyttn@outlook.com?${query}`;
});

/* ─── Scroll Reveal ───────────────────────────── */

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.12 }
);

document.querySelectorAll(".reveal").forEach((el) => revealObserver.observe(el));
