## تغییرات Container DI — توضیح تئوری

---

### ۱. Container به عنوان کلاس خالص (نه Singleton ماژول)

**قبل:** یک instance از Container در همان فایل ساخته و export می‌شد:

```js
const container = new Container(); // ← همیشه زنده است
module.exports = { container };
```

هر فایلی در پروژه می‌توانست `container` را import کند و مستقیماً `resolve()` صدا بزند. این یعنی container به یک **global state** تبدیل شده بود.

**بعد:** فقط کلاس export می‌شود. instance فقط یک بار، در **composition root** (یعنی server.js) ساخته می‌شود و به هیچ ماژول دیگری leak نمی‌کند.

---

### ۲. Circular Dependency Detection

**قبل:** اگر `A` به `B` و `B` به `A` وابسته بود، برنامه در یک حلقه بی‌نهایت گیر می‌کرد و Stack Overflow می‌داد — بدون هیچ پیام مفیدی.

**بعد:** Container یک `Set` به نام `_resolving` نگه می‌دارد. وقتی شروع به ساختن یک token می‌کند، آن را در Set می‌گذارد. اگر حین ساخت، همان token دوباره درخواست شود، فوراً خطا می‌دهد:

```
Circular dependency detected: serviceA → serviceB → serviceA
```

این **fail-fast** است — مشکل در startup کشف می‌شود نه runtime.

---

### ۳. Dependency Chain Trace در خطاها

**قبل:** اگر یک token ثبت نشده بود، خطا فقط می‌گفت:

```
No binding for token: "fooService"
```

معلوم نبود کدام سرویس این درخواست را داد.

**بعد:** هر factory به جای دریافت کل container، یک **resolver proxy** می‌گیرد که chain را با خود حمل می‌کند. خطا اکنون مسیر کامل را نشان می‌دهد:

```
No binding found for "dbPool" (while resolving: usersService → userRepository → dbPool)
```

---

### ۴. Resolver Proxy به جای دسترسی مستقیم به Container

**قبل:** هر factory، کل container را می‌گرفت:

```js
(c) => new UserRepository(c.resolve("db"));
```

این یعنی factory می‌توانست هر چیزی از container بکشد — هیچ کنترلی نبود.

**بعد:** factory فقط یک object کوچک می‌گیرد:

```js
({ resolve }) => new UserRepository(resolve("db"));
```

این object فقط `resolve` و `resolveAsync` دارد. factory نمی‌تواند به متدهای داخلی container دسترسی داشته باشد. به علاوه، این resolver همان chain را برای trace خطا نگه می‌دارد.

---

### ۵. Async Factory Support

**قبل:** Container فقط sync بود. اگر یک factory مثلاً نیاز داشت قبل از ساخت یک سرویس یک کانکشن async برقرار کند، راهی وجود نداشت.

**بعد:** دو مسیر موازی وجود دارد:

- `resolve()` ← sync، اگر نتیجه یک Promise باشد خطا می‌دهد
- `resolveAsync()` ← async، هر دو نوع factory را handle می‌کند
- `verifyAsync()` ← نسخه async از `verify()` برای startup check

---

### ۶. محافظت در برابر ثبت تکراری

**قبل:** اگر یک token دو بار ثبت می‌شد، binding دوم بدون خطا جایگزین اول می‌شد. این باعث می‌شد در پروژه‌های بزرگ به‌سختی قابل تشخیص باشد که کدام implementation فعال است.

**بعد:** `_guardDuplicate()` قبل از هر ثبت بررسی می‌کند. ثبت تکراری فوراً خطا می‌دهد.

---

### ۷. پشتیبانی از Symbol به عنوان Token

**قبل:** token فقط string بود و در پیام‌های خطا `[object Symbol]` نمایش داده می‌شد.

**بعد:** متد `_name(token)` نوع token را تشخیص می‌دهد و Symbol را به درستی نمایش می‌دهد: `Symbol(db)`. این برای پروژه‌هایی که می‌خواهند از collision اسم‌ها جلوگیری کنند مفید است.

---

### ۸. تقسیم Providers به سه لایه مجزا

**قبل:** یک فایل providers.js که همه چیز — infrastructure، repositories، services — را با هم ثبت می‌کرد.

**بعد:** سه فایل با مسئولیت مشخص:

| فایل              | مسئولیت                                                |
| ----------------- | ------------------------------------------------------ |
| infrastructure.js | اتصال‌های از پیش ساخته‌شده (`db`, `redis`, `bus`)      |
| repositories.js   | لایه data-access، فقط `db` می‌گیرند                    |
| services.js       | لایه application، فقط repository و dispatcher می‌گیرند |

ترتیب ثبت در index.js صریح است: **Infrastructure → Repositories → Services**. هیچ service ای نمی‌تواند تصادفی به `db` مستقیم وصل شود — چون `db` را نمی‌بیند.
