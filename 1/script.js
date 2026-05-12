const releaseBaseUrl = "https://github.com/vivokzizok-sys/veloce-express/releases/latest/download";

const defaultDownloads = [
  {
    key: "arm64",
    title: "نسخة arm64",
    subtitle: "الأفضل لمعظم الهواتف الحديثة",
    fileName: "nawdli-express-arm64.apk",
    version: "1.0.0",
    size: "42 MB",
    date: "2026-05-12",
    url: `${releaseBaseUrl}/nawdli-express-arm64.apk`
  },
  {
    key: "armv7",
    title: "نسخة armv7",
    subtitle: "نسخة احتياطية للهواتف الأقدم",
    fileName: "nawdli-express-armv7.apk",
    version: "1.0.0",
    size: "39 MB",
    date: "2026-05-12",
    url: `${releaseBaseUrl}/nawdli-express-armv7.apk`
  },
  {
    key: "x86_64",
    title: "نسخة x86_64",
    subtitle: "للمحاكيات وبعض الأجهزة الخاصة",
    fileName: "nawdli-express-x86_64.apk",
    version: "1.0.0",
    size: "44 MB",
    date: "2026-05-12",
    url: `${releaseBaseUrl}/nawdli-express-x86_64.apk`
  }
];

const firebaseConfig = {
  apiKey: "AIzaSyAvxTNotYH6Eibgj7bQgVF6kQCccjOUpHc",
  authDomain: "veloce-express.firebaseapp.com",
  projectId: "veloce-express",
  messagingSenderId: "391374475758"
};

const downloadsStorageKey = "veloce_downloads_preview";
let firebaseServices = null;
let currentAdmin = null;
let remoteDownloads = null;

function localDownloads() {
  try {
    return JSON.parse(localStorage.getItem(downloadsStorageKey)) || defaultDownloads;
  } catch (_) {
    return defaultDownloads;
  }
}

function getDownloads() {
  return remoteDownloads && remoteDownloads.length ? remoteDownloads : localDownloads();
}

function latestDownload() {
  return getDownloads()[0] || defaultDownloads[0];
}

function initFirebase() {
  if (firebaseServices || typeof firebase === "undefined") return firebaseServices;
  try {
    if (!firebase.apps.length) firebase.initializeApp(firebaseConfig);
    firebaseServices = {
      auth: firebase.auth(),
      db: firebase.firestore()
    };
    return firebaseServices;
  } catch (error) {
    console.warn("Firebase unavailable", error);
    return null;
  }
}

async function loadRemoteDownloads() {
  const services = initFirebase();
  if (!services) return;
  try {
    const doc = await services.db.collection("site_config").doc("downloads").get();
    if (doc.exists && Array.isArray(doc.data().items)) {
      remoteDownloads = doc.data().items;
      renderAll();
    }
  } catch (error) {
    console.warn("Remote download config unavailable", error);
  }
}

function downloadCard(item, index) {
  return `
    <article class="version-card reveal">
      <div>
        <h3>${item.title}</h3>
        <span>${item.fileName}</span>
      </div>
      <p>${item.subtitle}<br>الإصدار ${item.version} - الحجم ${item.size}</p>
      <a class="tag" href="${item.url}" download>${index === 0 ? "تحميل موصى به" : "تحميل بديل"}</a>
    </article>
  `;
}

function renderPublicDownloads() {
  const versionsList = document.querySelector("[data-versions-list]");
  const options = document.querySelector("[data-apk-options]");
  const cards = getDownloads().map(downloadCard).join("");
  if (versionsList) versionsList.innerHTML = cards;
  if (options) options.innerHTML = cards;
}

function renderCurrentRelease() {
  const latest = latestDownload();
  const strip = document.querySelector("[data-current-release]");
  const versionLabel = document.querySelector("[data-version-label]");
  const sizeLabel = document.querySelector("[data-size-label]");
  if (strip) {
    strip.innerHTML = `
      <span>الإصدار ${latest.version}</span>
      <span>الحجم ${latest.size}</span>
      <span>3 ملفات APK احتياطية</span>
    `;
  }
  if (versionLabel) versionLabel.textContent = latest.version;
  if (sizeLabel) sizeLabel.textContent = latest.size;
  document.querySelectorAll("[data-download-link]").forEach(link => {
    link.href = latest.url;
  });
}

function renderAdminPreview() {
  const latest = document.querySelector("[data-admin-latest]");
  const preview = document.querySelector("[data-admin-download-preview]");
  const form = document.querySelector("[data-downloads-form]");
  const downloads = getDownloads();
  if (latest) latest.textContent = downloads[0]?.version || "لا يوجد";
  if (preview) preview.innerHTML = downloads.map(downloadCard).join("");
  if (form && downloads.length >= 3) {
    form.version.value = downloads[0].version || "1.0.0";
    form.arm64Url.value = downloads[0].url || "";
    form.arm64Size.value = downloads[0].size || "";
    form.armv7Url.value = downloads[1].url || "";
    form.armv7Size.value = downloads[1].size || "";
    form.x64Url.value = downloads[2].url || "";
    form.x64Size.value = downloads[2].size || "";
  }
}

function renderAll() {
  renderPublicDownloads();
  renderCurrentRelease();
  renderAdminPreview();
  setupReveal();
}

async function assertAdmin(user) {
  const services = initFirebase();
  if (!services || !user) return false;
  const doc = await services.db.collection("users").doc(user.uid).get();
  return doc.exists && doc.data().role === "admin";
}

function setAdminVisible(visible) {
  document.querySelector("[data-auth-panel]")?.classList.toggle("is-hidden", visible);
  document.querySelectorAll("[data-admin-private]").forEach(node => {
    node.classList.toggle("is-hidden", !visible);
  });
}

function setAuthState(message) {
  const state = document.querySelector("[data-auth-state]");
  if (state) state.textContent = message;
}

function toast(message) {
  const node = document.querySelector("[data-toast]");
  if (!node) return;
  node.textContent = message;
  node.classList.add("show");
  window.setTimeout(() => node.classList.remove("show"), 2600);
}

function setupAdminAuth() {
  const services = initFirebase();
  const loginForm = document.querySelector("[data-login-form]");
  const logoutButton = document.querySelector("[data-logout-button]");
  if (!loginForm) return;

  if (!services) {
    setAuthState("Firebase غير متاح الآن. لا يمكن فتح لوحة الأدمن.");
    return;
  }

  setAdminVisible(false);
  services.auth.onAuthStateChanged(async user => {
    try {
      if (!user) {
        currentAdmin = null;
        setAdminVisible(false);
        setAuthState("سجل الدخول بحساب الأدمن.");
        return;
      }
      const allowed = await assertAdmin(user);
      if (!allowed) {
        await services.auth.signOut();
        setAuthState("هذا الحساب ليس أدمن داخل Firestore.");
        return;
      }
      currentAdmin = user;
      setAdminVisible(true);
      await loadRemoteDownloads();
      toast(`تم الدخول: ${user.email}`);
    } catch (error) {
      setAuthState(`تعذر التحقق من الأدمن: ${error.message}`);
    }
  });

  loginForm.addEventListener("submit", async event => {
    event.preventDefault();
    const form = new FormData(loginForm);
    try {
      await services.auth.signInWithEmailAndPassword(form.get("email"), form.get("password"));
      loginForm.reset();
    } catch (error) {
      setAuthState(`فشل تسجيل الدخول: ${error.message}`);
    }
  });

  logoutButton?.addEventListener("click", () => services.auth.signOut());
}

function setupForms() {
  const form = document.querySelector("[data-downloads-form]");
  if (!form) return;
  form.addEventListener("submit", async event => {
    event.preventDefault();
    const data = new FormData(form);
    const version = data.get("version");
    const items = [
      { ...defaultDownloads[0], version, url: data.get("arm64Url"), size: data.get("arm64Size") },
      { ...defaultDownloads[1], version, url: data.get("armv7Url"), size: data.get("armv7Size") },
      { ...defaultDownloads[2], version, url: data.get("x64Url"), size: data.get("x64Size") }
    ];
    const services = initFirebase();
    if (services && currentAdmin) {
      try {
        await services.db.collection("site_config").doc("downloads").set({
          items,
          updatedBy: currentAdmin.uid,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        remoteDownloads = items;
        localStorage.setItem(downloadsStorageKey, JSON.stringify(items));
        renderAll();
        toast("تم حفظ روابط التحميل");
        return;
      } catch (error) {
        toast(`فشل الحفظ: ${error.message}`);
        return;
      }
    }
    localStorage.setItem(downloadsStorageKey, JSON.stringify(items));
    remoteDownloads = items;
    renderAll();
    toast("تم حفظ الروابط محليًا");
  });
}

function setupHeader() {
  const header = document.querySelector("[data-header]");
  const button = document.querySelector("[data-menu-button]");
  const mobileNav = document.querySelector("[data-mobile-nav]");
  if (header) {
    window.addEventListener("scroll", () => {
      header.classList.toggle("scrolled", window.scrollY > 30);
    }, { passive: true });
  }
  if (button && mobileNav) {
    button.addEventListener("click", () => mobileNav.classList.toggle("open"));
    mobileNav.querySelectorAll("a").forEach(link => {
      link.addEventListener("click", () => mobileNav.classList.remove("open"));
    });
  }
}

function setupReveal() {
  const nodes = document.querySelectorAll(".reveal:not(.visible)");
  if (!("IntersectionObserver" in window)) {
    nodes.forEach(node => node.classList.add("visible"));
    return;
  }
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.14 });
  nodes.forEach(node => observer.observe(node));
}

renderAll();
setupAdminAuth();
setupForms();
setupHeader();
loadRemoteDownloads();
