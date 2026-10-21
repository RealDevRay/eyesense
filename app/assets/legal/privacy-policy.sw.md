# Sera ya Faragha ya EyeSense

**Tarehe ya kuanza kutumika:** 21 Oktoba 2026

**Ilihuishwa mara ya mwisho:** 21 Oktoba 2026

**Toleo:** 1.1-pilot

**Taarifa ya majaribio:** Huu ni rasimu inayohitaji mapitio, si uthibitisho wa kufuata sheria wala utayari wa uzalishaji. Tafsiri ya Kiswahili inahitaji mapitio ya mzungumzaji mzawa na mtaalamu wa sheria.

## 1. Sisi ni nani

EyeSense ("programu") ni programu ya usaidizi wa kuona inayotumia akili bandia, kwa watu wasioona na wenye uoni hafifu. Inatolewa na DevRay ("sisi", "yetu").

Unaweza kutuwasiliana kuhusu lolote katika sera hii kwa **info@devray.qzz.io**. Kama unahitaji sera hii katika muundo mwingine, au msaada wa kutumia haki yoyote iliyoelezwa hapa, tuwasiliane na tutakusaidia.

## 2. Muhtasari

- EyeSense haina akaunti za watumiaji. Hatukuulizi jina lako, barua pepe wala namba ya simu.
- **OCR ya Soma Maandishi (Read Text) hutambua maandishi ndani ya kifaa bila kutuma picha.** Utambuzi wa usemi na kusoma maandishi kwa sauti (TTS) za mfumo zinaweza kuhitaji mtandao; kusikiliza bila mtandao kunahitaji sauti ya nje ya mtandao iliyosakinishwa.
- **Eleza Mazingira (Describe Scene) na Uliza Swali (Ask a Question) hutuma picha moja kutoka kifaa chako**, na hiyo hutokea tu baada ya wewe mwenyewe kuwasha uchakataji wa mtandaoni.
- Hali ya seva yetu hutuma maombi kupitia Cloudflare Worker yetu kwenda Groq pekee. BYOK hutuma moja kwa moja kwa mtoa huduma uliyemchagua: Groq, OpenAI, Google Gemini, au Mistral ya hiari, kwa ufunguo wa mtoa huduma huyo. Hakuna kubadilisha mtoa huduma au modeli kimyakimya.
- Katika hali ya seva yetu, tunapokea anwani yako ya IP na kuhifadhi hesabu zinazotumia IP hiyo kudhibiti matumizi mabaya. Hatuhakikishi kufutwa usiku wa manane. Ona §3.7.
- Hatutumii matangazo, uchanganuzi, ufuatiliaji wa vyanzo wala huduma za kukufuatilia.
- Hatuuzi wala hatupangishi data yako, na DevRay haitumii data hiyo kufundisha mifumo ya akili bandia. **Katika Mistral Free mode, data ya ingizo na matokeo inaweza kutumika kufundisha modeli usipojiondoa katika akaunti yako ya Mistral. Free mode haina chaguo la kutohifadhi data kabisa (ZDR).** Ona §5.
- Ukaguzi wa hiari wa sensa za Android — accelerometer, gravity, gyroscope, mwanga na proximity ya mbele — ni wa muda mfupi ndani ya kifaa. Taarifa na sampuli za sensa hazitumwi mtandaoni. Ona §3.8.
- Kumbukumbu za kiufundi za uchunguzi zimezimwa hadi wewe uziwashe, na hubaki ndani ya kifaa chako.

## 3. Programu inachakata nini, na lini

### 3.1 Picha za kamera

| Kipengele | Kinachotokea kwa picha |
| --- | --- |
| **Soma Maandishi** | Picha hupigwa, maandishi hutambuliwa ndani ya kifaa kwa Google ML Kit, kisha picha hufutwa. Picha haitumwi kwa OCR; huduma za usemi ni tofauti — ona §3.3. |
| **Eleza Mazingira** | Hupigwa, hupunguzwa ukubwa, na hutumwa kwa mtoa huduma wa AI uliyeweka. Hufutwa kifaani baada ya kazi kukamilika. |
| **Uliza Swali** | Kama Eleza Mazingira, pamoja na swali lako. |

Eleza Mazingira na Uliza Swali hufanya kazi tu baada ya kuwasha **Ridhaa ya Uchakataji Mtandaoni**. Hadi ufanye hivyo, vipengele hivyo viwili havipatikani na hakuna picha ya kamera inayotumwa kwa uchanganuzi wa AI. Unaweza kuondoa ridhaa hiyo wakati wowote katika Mipangilio, na hilo husitisha papo hapo kutuma picha nyingine.

Kwa **1.1-pilot**, ridhaa ya mtandaoni iliyohifadhiwa yenye toleo la masharti la zamani au lisilopo huhesabiwa kuwa imezimwa. Soma taarifa zilizohuishwa na uwashe tena Ridhaa ya Uchakataji Mtandaoni katika Mipangilio. Kukamilisha mafunzo zamani hakukulazimishi kuyarudia; kusoma au kukubali masharti pekee hakuwashi tena ridhaa. Uthibitisho wa kusoma mipaka ya usalama pia una toleo, na wa zamani hauhesabiwi. **OCR ya Soma Maandishi bado inapatikana bila ridhaa ya mtandaoni.**

Picha hukaa kifaani kwa muda wa kazi hiyo tu, na hufutwa baadaye. Hatutunzi historia ya picha zako, na programu haina ghala la picha wala kipengele cha kuhifadhi majibu.

### 3.2 Maandishi ya swali lako

Unapotumia Uliza Swali, maneno ya swali lako hutumwa pamoja na picha kwa mtoa huduma wa AI uliyeweka. Programu haitunzi historia ya maswali iliyohifadhiwa; swali au jibu la sasa linaweza kubaki kwenye kumbukumbu hai kwa kuonyeshwa au kurudiwa.

### 3.3 Maikrofoni na usemi

Unapotumia kipengele cha sauti, programu huomba huduma ya utambuzi wa usemi ya kifaa chako cha Android isikilize na kubadilisha uliyosema kuwa maandishi. **Programu hupokea maandishi hayo pekee; haipokei, haihifadhi wala haitumi sauti yenyewe.**

Muhimu: ubadilishaji huo hufanywa na mtoa huduma wa usemi wa kifaa chako, ambaye katika vifaa vingi vya Android ni Google. Kutegemea kifaa chako, mipangilio yake ya lugha na usanidi wake, huduma hiyo inaweza kuchakata usemi wako ndani ya kifaa au kwenye seva za mtoaji. Uchakataji huo unaongozwa na sera ya faragha ya mtoa huduma wa kifaa chako, sio sera hii. Unaweza kuangalia na kubadilisha huduma ya usemi inayotumika katika mipangilio ya Android.

OCR ya Soma Maandishi haihitaji mtandao, lakini utambuzi wa usemi na TTS ni huduma tofauti za mfumo. Injini yako ya TTS inaweza kuchakata maandishi mtandaoni chini ya masharti yake. Sakinisha na uchague sauti ya nje ya mtandao kwa kusikiliza bila mtandao. Ridhaa ya AI ya mtandaoni haidhibiti huduma hizi za mfumo.

### 3.4 Vitambulisho vya mtoa huduma wako wa AI

Katika hali ya "Leta Ufunguo Wako" (BYOK), unachagua wazi Groq, OpenAI, Google Gemini, au Mistral ya hiari na unaweza kubadilisha kitambulisho cha modeli cha mtoa huduma huyo. Ufunguo wa API wa kila mtoa huduma huhifadhiwa kando kifaani katika hifadhi iliyosimbwa (`flutter_secure_storage` na `EncryptedSharedPreferences` ya Android). Hautumwi kwa EyeSense Worker. Hutumwa kwa mtoa huduma uliyemchagua kama kichwa cha uthibitisho; ufunguo wa mtoa huduma mwingine hautumiki. Unaweza kuondoa ufunguo wa mtoa huduma aliyechaguliwa katika Mipangilio; hilo haliondoi funguo za wengine.

Katika hali ya seva yetu, tokeni huruhusu kufikia Worker yetu. Si akaunti binafsi ya EyeSense wala utambulisho wa kila kifaa. Ufunguo wa Groq hukaa kwenye seva; Worker haipokei funguo zako za BYOK.

Hakuna hali inayobadilisha mtoa huduma au modeli kimyakimya ombi likishindwa. Hali ya seva yetu hutumia Groq pekee; BYOK huenda moja kwa moja kwa mtoa huduma aliyechaguliwa. Gemini hutumia kiunganishi rasmi cha Google kinachooana na OpenAI; maombi huenda Google, si OpenAI.

Mistral hutumia API rasmi isiyobadilishwa `https://api.mistral.ai/v1`: `POST /chat/completions` kwa uchakataji na `GET /models` kwa ukaguzi wa modeli. Hutumia ufunguo wako wa Mistral tu, si ufunguo wa mtoa huduma mwingine wala tokeni ya seva yetu. Modeli ya chaguo-msingi ni `mistral-small-latest`; jina hili linaweza kuelekeza toleo jipya na upatikanaji haujahakikishwa. Haichaguliwi kama mbadala wa kiotomatiki.

### 3.4.1 Ukaguzi wa muunganisho wa hiari

**Check key and model** hutuma ombi la `GET /models` lenye uthibitisho kwa mtoa huduma aliyechaguliwa kwa ufunguo ulioingizwa. Haitumi picha au swali, haitumii kamera wala kufanya uchakataji wa AI. Huangalia uthibitisho na kama modeli imeorodheshwa; haithibitishi uwezo wa picha au JSON.

**Jaribio la picha ya mfano iliyozalishwa** ni tofauti. Linahitaji ridhaa ya AI ya mtandaoni na uthibitisho mwingine kabla ya kutuma picha nyekundu iliyozalishwa ya 64 × 64 kwa mtoa huduma aliyechaguliwa kwa ufunguo na modeli zilizoingizwa. Halitumii kamera wala picha binafsi. Ni ombi moja la uchakataji linaloweza kutozwa kwenye akaunti yako, bila kurudia kiotomatiki. Hakuna ukaguzi unaohifadhi mipangilio ya muunganisho kiotomatiki; kuhifadhi ni hatua tofauti.

### 3.5 Kumbukumbu za uchunguzi

Kumbukumbu za uchunguzi **zimezimwa kwa kawaida**. Kama utaziwasha, programu huandika taarifa za kiufundi kwenye faili ndani ya kifaa chako, zenye muda wa kazi, kodi za hitilafu na idadi ya tokeni.

Kumbukumbu hizi hazina picha za kamera, sauti, maswali yako, maandishi yaliyotambuliwa, wala funguo za API. Hubaki kifaani. Hazitumwi kwetu. Unaweza kuona ukubwa wa faili, kuisafirisha, au kuifuta wakati wowote katika Mipangilio. Kuisafirisha hutuma faili mahali unapochagua, na kuanzia hapo sera hii haiiongozi tena.

### 3.6 Mipangilio yako

Mapendeleo yako — pamoja na wasifu wa usaidizi, usemi, mtetemo, muonekano, ridhaa, hatua ya mafunzo, mtoa huduma na modeli za kila mtoa huduma — huhifadhiwa kifaani. Lugha ya jibu na modeli iliyochaguliwa hujumuishwa katika maombi husika ya AI; nakala ya mapendeleo yako haitumwi.

### 3.7 Anwani yako ya IP, katika hali ya seva yetu

Unapotumia Eleza Mazingira au Uliza Swali kwa njia ya seva yetu, ombi lako hufika kwenye seva yetu kupitia mtandao, hivyo seva yetu hupokea **anwani yako ya IP** bila kuepukika.

Tunatumia anwani halisi ya IP kama ufunguo wa hesabu za maombi ya dakika moja kwa kila mteja. Hii inajumuisha ukomo kabla ya kuchanganua ombi, hata ombi lenye uthibitisho likikataliwa baadaye kwa hitilafu au njia iliyozimwa. Funguo na hesabu hizi huhifadhiwa katika Cloudflare Durable Object. Pia tunahifadhi jumla za maombi ya dakika na siku na nafasi za maombi yanayoendelea zenye muda wa kuisha; hizi hazitumii ufunguo wa mteja na zinashirikiwa na watumiaji wote wa seva ya majaribio.

Operesheni inayofuata ya ukomo kabla ya kuchanganua, kuhesabu matumizi au kuachia nafasi hufuta madirisha ya IP ya dakika moja yaliyokwisha na nafasi za maombi zilizokwisha (sekunde 60). Kuachia nafasi kwa mafanikio pia huiondoa. Jumla ya siku huanza upya operesheni ya baadaye inapoona tarehe mpya ya UTC; madirisha ya dakika yanaweza kuvuka usiku wa manane. **Hakuna kengele ya kufuta iliyopangwa wala uhakika wa kufutwa muda unapoisha au saa 00:00 UTC. Taarifa zinaweza kubaki huduma ikiwa haitumiki hadi operesheni ya baadaye.**

Vikomo vya chaguo-msingi vya seva ya majaribio ni **maombi 6 kwa dakika kwa jumla, nafasi 2 za maombi kwa wakati mmoja, na maombi 100 kwa siku ya UTC kwa jumla**. Mwendeshaji anaweza kuvisanidi. Si ahadi ya mgao binafsi, mafanikio ya uchakataji au upatikanaji; vikomo vya akaunti ya mtoa huduma pia hutumika.

Hatutumii hesabu hizi kuunda wasifu binafsi au kubashiri mahali ulipo. Hata hivyo, ni kumbukumbu ya seva inayotumia anwani halisi ya IP, si takwimu zisizotambulisha. Uchakataji wa mtandao wa Cloudflare pia unaongozwa na sera zake.

Katika BYOK, maombi ya AI huenda moja kwa moja kwa mtoa huduma aliyechaguliwa, si Worker yetu. Mtoa huduma huyo hupokea anwani yako ya mtandao chini ya masharti yake.

### 3.8 Ukaguzi wa hiari wa sensa za Android ndani ya kifaa

EyeSense inaweza kusoma upatikanaji na sampuli fupi za **accelerometer, gravity, gyroscope, mwanga wa mazingira na proximity ya mbele**. Kugundua upatikanaji hakuanzishi sampuli. Sampuli hukusanywa kwa **chini ya sekunde moja**, wakati wa kupiga picha kwa mwongozo uliochaguliwa au kitufe cha **Check sensors now** tu; Sitisha, kughairi na kuondoka kwenye programu husimamisha ukaguzi. Hakuna ufuatiliaji wa nyuma unaoendelea.

Taarifa na sampuli hubaki kwenye kumbukumbu hai ya kifaa kwa ukaguzi au onyesho la sasa. Hazihifadhiwi kama historia, haziwekwi katika kumbukumbu za uchunguzi wala kutumwa mtandaoni. **Hakuna GPS, dira wala sensa za mahali zinazotumiwa.**

Accelerometer/gravity hukadiria mkao wa simu dhidi ya mvutano wa dunia, si upangaji wa ukurasa. Gyroscope huashiria mtikisiko, si mwelekeo wa dira wala umbali. Mwanga ni dalili ya jumla tu. Proximity huashiria sensa ya **MBELE** kufunikwa, si umbali wa kitu kinachoonekana na kamera ya nyuma wala kizuizi. Hakuna ukaguzi unaothibitisha usalama wa njia, fremu sahihi ya ukurasa au urambazaji. Kukosekana kwa sensa au onyo si uthibitisho wa usalama au ubora wa picha. Tabia ya vifaa halisi na ufikivu bado vinahitaji kupimwa.

## 4. Tusichofanya

- Hatuunda akaunti wala wasifu wa watumiaji.
- Hatukusanyi mahali ulipo. Programu haiombi ruhusa ya mahali.
- Hatutumii vidakuzi, vitambulisho vya matangazo wala unukuu wa kifaa.
- Hatujumuishi huduma za matangazo, uchanganuzi, ufuatiliaji wa vyanzo wala kuripoti hitilafu.
- Hatuuzi, hatupangishi wala hatubadilishani data yoyote.
- Hatutumii picha zako, maswali yako wala maudhui mengine kufundisha mifumo ya akili bandia.
- Hatukufuatilii kwenye programu nyingine au tovuti nyingine.

## 5. Nani wengine wanahusika

Unapotumia kipengele cha mtandaoni, picha na swali au maagizo ya jaribio huchakatwa na wahusika katika njia uliyochagua. Hatudhibiti mifumo yao. Groq ni mwenyeji wa uchakataji wa modeli ya Qwen (`qwen/qwen3.8-27b` kwa chaguo-msingi), si jina la modeli. Chaguo-msingi za BYOK ni `gpt-5-mini` kwa OpenAI, `gemini-3.8-flash` kwa Google Gemini na `mistral-small-latest` kwa Mistral ya hiari; modeli zinaweza kubadilishwa na si dhamana ya upatikanaji au uwezo.

| Mhusika | Jukumu | Wanachopokea | Sera yao ya faragha |
| --- | --- | --- | --- |
| **Cloudflare, Inc.** | Huendesha seva yetu ya kupokea maombi, katika hali ya seva yetu | Ombi linapopita, pamoja na picha, na anwani yako ya IP | [cloudflare.com/privacypolicy](https://www.cloudflare.com/privacypolicy/) |
| **Groq LLC** | Mwenyeji wa uchakataji katika hali ya seva yetu, au BYOK ikiwa Groq ndiye aliyechaguliwa | Picha na swali/maagizo ya jaribio; ufunguo wa Groq na anwani ya mtandao katika BYOK | [Sera ya Groq](https://groq.com/privacy-policy) |
| **OpenAI** | Uchakataji wa moja kwa moja ikiwa OpenAI ndiye mtoa huduma wa BYOK aliyechaguliwa pekee | Picha na swali/maagizo ya jaribio, ufunguo wa OpenAI na anwani ya mtandao | [Sera ya OpenAI](https://openai.com/policies/privacy-policy/) |
| **Google — Gemini API** | Uchakataji wa moja kwa moja ikiwa Google Gemini ndiye aliyechaguliwa pekee, kwa kiunganishi cha Google kinachooana na OpenAI | Picha na swali/maagizo ya jaribio, ufunguo wa Gemini na anwani ya mtandao | [Masharti ya Gemini API](https://ai.google.dev/gemini-api/terms) na [sera ya Google](https://policies.google.com/privacy) |
| **Mistral AI** | Uchakataji wa moja kwa moja ikiwa Mistral imechaguliwa wazi katika BYOK kwa API yake rasmi | Picha na swali/maagizo ya jaribio, ufunguo wako wa Mistral na anwani ya mtandao | [Sera ya Mistral](https://legal.mistral.ai/terms/privacy-policy) na [masharti](https://legal.mistral.ai/terms) |
| **Google / mtoa huduma wa usemi wa mfumo aliyechaguliwa** | OCR ya ML Kit kifaani; huduma tofauti za utambuzi wa usemi na TTS | Picha ya OCR haitumwi. Huduma ya usemi inaweza kupokea usemi au maandishi — ona §3.3 | [Sera ya Google](https://policies.google.com/privacy); angalia pia masharti ya mtoa huduma wako wa usemi |

**Tafadhali soma haya kwa makini:** ombi likishapokelewa na mtoa huduma wa AI, linakuwa chini ya masharti yake ya uchakataji na kuhifadhi, na **sisi hatuwezi kuliondoa**. Kusitisha kazi ndani ya programu hughairi ombi letu; hakusitishi lazima uchakataji ambao mtoa huduma ameanza, wala malipo yanayohusiana nayo.

Katika BYOK, maombi huenda moja kwa moja kwa **mtoa huduma aliyechaguliwa** kwa akaunti yako mwenyewe, chini ya makubaliano yako naye, vikomo na malipo yake. Kufuta picha kifaani hakuthibitishi kufutwa kwa mtoa huduma, kutohifadhiwa au kutotumika kufundisha AI.

**Onyo la Mistral Free mode:** ingizo na matokeo yanaweza kutumika kufundisha modeli usipojiondoa katika akaunti yako (Admin → Privacy → Anonymous improvement data). EyeSense haikagui wala kubadilisha chaguo hilo. Kujiondoa si kutohifadhi data: **Free mode haina ZDR**; mipango ya kulipia inayostahiki inahitaji idhini ya mtoa huduma. Usidhani data hufutwa moja kwa moja. Ukurasa wa Limits na masharti ya akaunti yako ndiyo rejeo la sasa; ufunguo wa bure hauhakikishi ufikiaji wa modeli za picha, mgao uliobaki, msaada au kutegemewa. Hakuna jaribio la moja kwa moja la Mistral lililofanywa. Ona [maelezo ya mafunzo](https://help.mistral.ai/en/articles/347617-do-you-use-my-user-data-to-train-your-artificial-intelligence-models), [kujiondoa](https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training) na [ZDR](https://help.mistral.ai/en/articles/347612-can-i-activate-zero-data-retention-zdr).

Viungo hivi rasmi ni vya rejeo, si dai kwamba sera za watoa huduma wapya zimepitiwa. Mapitio ya masharti ya sasa ya API, aina ya akaunti, uchakataji, uhifadhi, matumizi ya kufundisha AI na uhamishaji wa kimataifa yanahitajika kabla ya uzinduzi au matumizi ya taarifa nyeti. Masharti yanaweza kubadilika.

## 6. Kwa nini tunaruhusiwa kuchakata haya

Pale sheria ya ulinzi wa data inahitaji msingi wa kisheria, tunategemea:

- **Ridhaa yako**, kwa kutuma picha na maswali kwa mtoa huduma wa AI mtandaoni. Unaitoa wazi na unaweza kuiondoa wakati wowote katika Mipangilio. Kuiondoa hakuathiri uchakataji uliokwisha kamilika.
- **Utekelezaji wa makubaliano yetu na wewe**, kwa uchakataji wa ndani ya kifaa unaohitajika ili programu ifanye kazi kabisa.
- **Maslahi yetu halali**, kwa kulinda huduma ya seva yetu dhidi ya matumizi mabaya na gharama kubwa, kwa kutumia anwani yako ya IP kama ilivyoelezwa katika §3.7.

## 7. Muda wa kuhifadhi

| Data | Muda wa kuhifadhi |
| --- | --- |
| Picha za kamera kifaani | Hufutwa baada ya kila kazi |
| Picha na maswali yaliyo kwa watoa huduma wa AI | Yanaongozwa na masharti ya mtoa huduma, sio sisi — ona §5 |
| Kumbukumbu za uchunguzi | Kifaani hadi uzifute au uondoe programu |
| Mipangilio na funguo za API | Kifaani hadi ziondolewe au programu iondolewe; funguo ziko kando kwa kila mtoa huduma |
| Taarifa na sampuli za sensa za kifaa | Kumbukumbu hai ya ukaguzi/onyesho la sasa tu; hazihifadhiwi wala kutumwa — ona §3.8 |
| Hesabu zinazotumia anwani halisi ya IP | Madirisha ya dakika moja yaliyokwisha hufutwa kwa operesheni ya baadaye; hakuna ufutaji wa muda uliohakikishwa — ona §3.7 |
| Jumla za matumizi na nafasi za maombi | Jumla za dakika/siku huanza upya kwa operesheni za baadaye; nafasi huisha baada ya sekunde 60 na kufutwa kwa operesheni ya baadaye au kuachiliwa; si za kila mteja |

## 8. Usalama

- Mawasiliano yote ya mtandao hutumia HTTPS. Usanidi wa usalama wa mtandao wa Android unakataza mawasiliano yasiyosimbwa katika matoleo ya uzinduzi.
- Funguo zako za API huhifadhiwa kando kwa kila mtoa huduma katika hifadhi iliyosimbwa kwa `EncryptedSharedPreferences` ya Android.
- `android:allowBackup="false"` huzuia vitambulisho vyako vilivyohifadhiwa kunakiliwa kwenye nakala rudufu za mtandaoni za kifaa.
- Huduma yetu ya seva hutunza vitambulisho vya watoa huduma kama siri za seva; haviko ndani ya programu.

Hakuna mfumo ulio salama kikamilifu. Hatuwezi kuhakikisha usalama kamili, na hupaswi kutumia EyeSense kupiga picha ya kitu unachokiona kuwa cha siri kubwa.

## 9. Watoto

EyeSense hailengi watoto, na hatuchakati kwa kujua data ya watoto. Kama unaamini mtoto ametumia programu kwa njia inayokutia wasiwasi, tuwasiliane kwa info@devray.qzz.io na tutakusaidia.

## 10. Uhamishaji wa kimataifa

Watoa huduma na miundombinu katika §5 wanaweza kuchakata data katika nchi nyingine, pamoja na Marekani. Njia iliyochaguliwa huamua anayepokea picha, swali/maagizo ya jaribio na anwani ya mtandao. Mtoa huduma wetu wa mtandao hupokea maombi ya seva yetu; BYOK huenda moja kwa moja kwa mtoa huduma aliyechaguliwa. Taarifa hii haithibitishi utaratibu wa uhamishaji unaotosheleza sheria; mapitio yanahitajika.

Kuepuka kutuma picha kwa AI mtandaoni, acha ridhaa imezimwa na utumie OCR ya **Soma Maandishi**. Kwa usemi bila mtandao pia, epuka utambuzi wa usemi wa mtandaoni na uchague sauti ya TTS ya nje ya mtandao iliyosakinishwa. Ridhaa ya AI pekee haidhibiti huduma za usemi.

## 11. Haki zako

Kutegemea unapoishi, unaweza kuwa na haki za kupata, kusahihisha, kufuta, kuzuia au kupinga uchakataji wa data yako binafsi, kuondoa ridhaa, na kulalamika kwa mdhibiti.

EyeSense haina akaunti za watumiaji, lakini seva yetu huhifadhi hesabu zenye anwani halisi za IP kama §3.7 inavyoeleza. Udhibiti mwingi unapatikana kifaani:

- **Kuondoa ridhaa:** zima Ridhaa ya Uchakataji Mtandaoni katika Mipangilio.
- **Kufuta data ya kifaani:** futa kumbukumbu za uchunguzi na uondoe kila ufunguo wa mtoa huduma katika Mipangilio, au uondoe programu. Hili halifuti data iliyo kwa mtoa huduma wala hesabu za IP kwenye seva yetu.
- **Kusitisha uhamishaji wa AI:** acha ridhaa imezimwa na utumie OCR ya Soma Maandishi. Huduma za usemi zina mipangilio tofauti — ona §3.3.

Kwa lolote usiloweza kufanya mwenyewe, wasiliana na **info@devray.qzz.io** na tutajibu ndani ya **siku 30**. Tunaweza kushindwa kutekeleza ombi la data tusiyoweza kuihusisha na wewe — mara nyingi hatuna data yoyote.

Unaweza pia kulalamika kwa mamlaka ya ulinzi wa data ya nchi yako.

## 12. Mabadiliko ya sera hii

Tutahuisha sera hii, tarehe na toleo lake pale tabia ya programu inabadilika. Toleo la majaribio la 1.1-pilot linahitaji ridhaa mpya ya mtandaoni ikiwa toleo lililokubaliwa ni la zamani au halipo, kama §3.1 inavyoeleza. Kuchapisha matoleo yaliyotangulia katika [eyesense.dpdns.org/sw/privacy/history](https://eyesense.dpdns.org/sw/privacy/history) na kuthibitisha taarifa ya mapitio inayofikika ndani ya programu bado ni kazi kabla ya uzinduzi. Kusasisha faili hizi si dai kwamba nyaraka zimechapishwa au zimepimwa kwenye kifaa halisi.

## 13. Upatikanaji wa sera hii

Sera hii inapatikana ndani ya programu kama maandishi yanayoweza kusomwa na kisomaji skrini, na pia katika [eyesense.dpdns.org/sw/privacy](https://eyesense.dpdns.org/sw/privacy). Kama unaihitaji katika muundo mwingine au lugha nyingine, tuwasiliane na tutaitoa.

---

*Toleo la Kiingereza la sera hii ni rejeo rasmi pale tafsiri inatofautiana. Mabadiliko haya ya tafsiri ni ya juhudi bora; mapitio ya mzungumzaji mzawa wa Kiswahili na mtaalamu wa sheria bado yanahitajika kabla ya uzinduzi.*
