const loginForm = document.querySelector("#login-form");
const passwordInput = document.querySelector("#password");
const visibilityButton = document.querySelector(".visibility-button");

visibilityButton.addEventListener("click", () => {
  const isPasswordVisible = passwordInput.type === "text";
  passwordInput.type = isPasswordVisible ? "password" : "text";
  visibilityButton.setAttribute(
    "aria-label",
    isPasswordVisible ? "Tampilkan kata sandi" : "Sembunyikan kata sandi",
  );
});

loginForm.addEventListener("submit", (event) => {
  event.preventDefault();
  window.location.assign("dashboard.html");
});
