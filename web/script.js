const careerForm = document.querySelector("#career-form");
const cvInput = careerForm.elements.namedItem("cv");
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

  const fields = new FormData(careerForm);
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
    "Opening your email app. Your CV is not attached automatically—please attach it before sending.";
  window.location.href = `mailto:godlyttn@outlook.com?${query}`;
});
