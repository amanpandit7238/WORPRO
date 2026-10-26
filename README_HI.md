# WORPRO Starter Project (Hindi + English)

यह एक शुरुआती runnable web-app project है, अंतिम production system नहीं। इसे AppsGeyser में पैक करने से पहले इसे HTTPS वेबसाइट पर होस्ट करना होगा।

## शामिल फ़ाइलें
- `index.html` — मोबाइल-फ्रेंडली UI: customer booking, worker application, bookings, admin panel, Hindi/English.
- `supabase/schema.sql` — database tables और Row Level Security (RLS) की शुरुआती policies.

## मुफ़्त शुरुआत के चरण
1. Supabase पर नया project बनाएँ।
2. SQL Editor खोलें और `supabase/schema.sql` चलाएँ।
3. Project Settings / API से Project URL और publishable (या anon) key लें।
4. `index.html` में `SUPABASE_URL` और `SUPABASE_ANON_KEY` भरें।
   - `service_role` key कभी भी HTML/ऐप में न डालें।
5. `index.html` को HTTPS static hosting पर प्रकाशित करें (जैसे किसी static-site host पर नया project)।
6. वेबसाइट URL को AppsGeyser में Website/WebView ऐप के रूप में डालें और टेस्ट APK बनाएँ।
7. ऐप को किसी वास्तविक ग्राहक/वर्कर को देने से पहले अलग-अलग अकाउंट से पूरा टेस्ट करें।

## पहला admin सुरक्षित तरीके से बनाना
1. ऐप से अपने ईमेल का अकाउंट बनाएँ।
2. Supabase Dashboard → Authentication → Users में उस user का UUID कॉपी करें।
3. SQL Editor में यह चलाएँ:
   `update public.profiles set role='admin' where id='YOUR-USER-UUID';`
4. टीम अकाउंट को `team` role दें, केवल उतनी अनुमति दें जितनी उन्हें चाहिए। यह starter अभी coarse role (team/admin) देता है; production में granular permissions और audit log जोड़ना चाहिए।

## सीमाएँ — लॉन्च से पहले पूरा करना ज़रूरी
- इस starter में वास्तविक ₹25 भुगतान नहीं है; केवल फीस का रिकॉर्ड/देय राशि है। भुगतान के लिए payment gateway और server-side verification चाहिए।
- WhatsApp का वास्तविक auto-dispatch नहीं जुड़ा है। इसके लिए WhatsApp Business Platform/Cloud API, verified business setup, approved templates/consent, server-side secret storage और delivery/retry logging चाहिए।
- Booking create होने पर matching workers को assignment rows बनाने के लिए trusted server function/Edge Function जोड़ना होगा। अभी schema में assignment table है, पर automatic assignment engine नहीं है।
- Worker को ग्राहक का नंबर/पूरा पता दिखाने वाला कोई endpoint न बनाएँ। Admin-only personal data को public worker messages में न भेजें।
- Customer cancellation, admin status transitions, commission ledger creation, fee confirmation, team permissions, password reset, privacy policy, terms, backups, rate limits, abuse prevention, and audit logs को production से पहले implement/test करें.
- Supabase SQL policies को वास्तविक deployment से पहले security review और test करें; database views और role privileges भी verify करें।
- ग्राहक के डेटा के लिए privacy notice/consent लें; केवल आवश्यक जानकारी इकट्ठा करें।
- कोई API secret, database password या service-role key APK/HTML में कभी न रखें।

## अभी क्या काम करता है?
बिना Supabase configuration के UI demo mode में खुलता है, लेकिन कोई online record save नहीं होता। Supabase configure होने पर signup/login और शुरुआती booking/worker application flows इस्तेमाल किए जा सकते हैं, बशर्ते schema/policies सही तरह deploy हों। Admin role को manually assign करना पड़ता है। इसे “पूर्ण production app” न समझें।
