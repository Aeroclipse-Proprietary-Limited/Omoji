/* ─── Modal ───────────────────────────────────── */

const modal   = document.getElementById("apply-modal");
const openBtns = document.querySelectorAll(".careers-apply-btn");
const closeBtn = document.getElementById("close-apply-modal");
let lastApplyTrigger = null;

function openModal(event) {
  lastApplyTrigger = event.currentTarget;
  modal.classList.add("is-open");
  document.body.style.overflow = "hidden";
  closeBtn.focus();
}

function closeModal() {
  modal.classList.remove("is-open");
  document.body.style.overflow = "";
  lastApplyTrigger?.focus();
}

openBtns.forEach((button) => button.addEventListener("click", openModal));
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

const revealElements = document.querySelectorAll(".reveal");
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (reduceMotion || !("IntersectionObserver" in window)) {
  revealElements.forEach((element) => element.classList.add("is-visible"));
} else {
  let lastScrollY = window.scrollY;
  let scrollingDown = true;

  window.addEventListener(
    "scroll",
    () => {
      scrollingDown = window.scrollY >= lastScrollY;
      lastScrollY = window.scrollY;
    },
    { passive: true }
  );

  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        const element = entry.target;

        if (entry.isIntersecting) {
          element.dataset.revealInView = "true";
          element.style.setProperty(
            "--reveal-offset-y",
            scrollingDown ? "88px" : "-88px"
          );
          requestAnimationFrame(() => {
            if (element.dataset.revealInView === "true") {
              element.classList.add("is-visible");
            }
          });
        } else {
          element.dataset.revealInView = "false";
          if (!element.classList.contains("is-visible")) return;

          element.classList.remove("is-visible");
          element.style.setProperty(
            "--reveal-offset-y",
            scrollingDown ? "-88px" : "88px"
          );
        }
      });
    },
    { threshold: 0 }
  );

  revealElements.forEach((element) => revealObserver.observe(element));
}

// A restrained, cursor-following glow adds a little response on mouse devices.
if (!reduceMotion && window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
  let pointerFrame = 0;
  let pointerX = 0;
  let pointerY = 0;

  window.addEventListener("pointermove", (event) => {
    if (event.pointerType !== "mouse" && event.pointerType !== "pen") return;
    pointerX = event.clientX;
    pointerY = event.clientY;
    if (pointerFrame) return;

    pointerFrame = requestAnimationFrame(() => {
      document.documentElement.style.setProperty("--pointer-x", `${pointerX}px`);
      document.documentElement.style.setProperty("--pointer-y", `${pointerY}px`);
      document.body.classList.add("has-pointer-glow");
      pointerFrame = 0;
    });
  }, { passive: true });

  window.addEventListener("pointerout", (event) => {
    if (event.relatedTarget === null) {
      document.body.classList.remove("has-pointer-glow");
    }
  }, { passive: true });
}

// Touch controls and cards briefly swell on contact, then settle back.
if (!reduceMotion) {
  document.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "touch") return;
    const target = event.target.closest("a.button, button, .feature-card, .edition-card");
    if (!target) return;

    target.classList.remove("touch-bloom");
    requestAnimationFrame(() => target.classList.add("touch-bloom"));
    target.addEventListener("animationend", () => {
      target.classList.remove("touch-bloom");
    }, { once: true });
  }, { passive: true });
}
