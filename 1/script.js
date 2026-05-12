const githubOwner = "vivokzizok-sys";
const githubRepo = "Nawdli-Express";
const releaseBaseUrl =
  `https://github.com/${githubOwner}/${githubRepo}/releases/download/android-latest`;

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

const downloadsStorageKey = "nawdli_downloads_preview";
let firebaseServices = null;
let currentAdmin = null;
let remoteDownloads = null;

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function safeApkUrl(value) {
  const raw = String(value ?? "").trim();
  if (/^public\/[A-Za-z0-9._/-]+\.apk$/.test(raw)) return raw;
  try {
    const url = new URL(raw);
    const allowed =
      url.protocol === "https:" &&
      url.hostname === "github.com" &&
      url.pathname.startsWith(`/${githubOwner}/${githubRepo}/releases/`) &&
      url.pathname.endsWith(".apk");
    return allowed ? url.toString() : "#";
  } catch (_) {
    return "#";
  }
}

function cleanDownload(item, fallback = defaultDownloads[0]) {
  const cleanUrl = safeApkUrl(item?.url || fallback.url);
  const source = cleanUrl === "#" ? fallback : item;
  return {
    key: String(source?.key || fallback.key || ""),
    title: String(source?.title || fallback.title || ""),
    subtitle: String(source?.subtitle || fallback.subtitle || ""),
    fileName: String(source?.fileName || fallback.fileName || ""),
    version: String(source?.version || fallback.version || ""),
    size: String(source?.size || fallback.size || ""),
    date: String(source?.date || fallback.date || ""),
    url: cleanUrl === "#" ? fallback.url : cleanUrl
  };
}

function localDownloads() {
  try {
    const parsed = JSON.parse(localStorage.getItem(downloadsStorageKey));
    return Array.isArray(parsed) ? parsed : defaultDownloads;
  } catch (_) {
    return defaultDownloads;
  }
}

function getDownloads() {
  const source =
    remoteDownloads && remoteDownloads.length ? remoteDownloads : localDownloads();
  return source
    .slice(0, 3)
    .map((item, index) => cleanDownload(item, defaultDownloads[index]));
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
  if (!document.querySelector("[data-admin-private]")) return;
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
  const safe = cleanDownload(item, defaultDownloads[index]);
  const label = index === 0 ? "تحميل موصى به" : "تحميل بديل";
  return `
    <article class="version-card reveal">
      <div>
        <h3>${escapeHtml(safe.title)}</h3>
        <span>${escapeHtml(safe.fileName)}</span>
      </div>
      <p>${escapeHtml(safe.subtitle)}<br>الإصدار ${escapeHtml(safe.version)} - الحجم ${escapeHtml(safe.size)}</p>
      <a class="tag" href="${safe.url}" rel="noopener" download>${label}</a>
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
  const strip = document.querySelector("[data-version-strip]");
  const versionLabel = document.querySelector("[data-version-label]");
  const sizeLabel = document.querySelector("[data-size-label]");
  if (strip) {
    strip.innerHTML = `
      <span>الإصدار ${escapeHtml(latest.version)}</span>
      <span>الحجم ${escapeHtml(latest.size)}</span>
      <span>3 ملفات APK احتياطية</span>
    `;
  }
  if (versionLabel) versionLabel.textContent = latest.version;
  if (sizeLabel) sizeLabel.textContent = latest.size;
  document.querySelectorAll("[data-download-link]").forEach(link => {
    link.href = safeApkUrl(latest.url);
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
  if (!services || !user || !user.emailVerified) return false;
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
    setAuthState("الخدمة غير متاحة الآن. لا يمكن فتح لوحة الأدمن.");
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
        setAuthState("هذا الحساب ليس أدمن أو البريد غير مؤكد.");
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
      await services.auth.signInWithEmailAndPassword(
        form.get("email"),
        form.get("password")
      );
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
    const version = String(data.get("version") || "").trim().slice(0, 32);
    const items = [
      {
        ...defaultDownloads[0],
        version,
        url: data.get("arm64Url"),
        size: String(data.get("arm64Size") || "").slice(0, 32)
      },
      {
        ...defaultDownloads[1],
        version,
        url: data.get("armv7Url"),
        size: String(data.get("armv7Size") || "").slice(0, 32)
      },
      {
        ...defaultDownloads[2],
        version,
        url: data.get("x64Url"),
        size: String(data.get("x64Size") || "").slice(0, 32)
      }
    ].map((item, index) => cleanDownload(item, defaultDownloads[index]));

    if (items.some(item => item.url === "#")) {
      toast("استخدم روابط APK صحيحة فقط");
      return;
    }

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
