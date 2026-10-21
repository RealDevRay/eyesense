# EyeSense

**Dunia yako, imeelezwa.**

EyeSense ni programu ya majaribio ya taarifa za kuona kwa watu wasioona na wenye uoni hafifu, pamoja na wanaotumia simu hiyo hiyo wakisaidiwa na mtu anayeona. Inaelezea picha moja ya kamera kwa wakati, na inaweza kukosea.

## Inafanya nini

- **Soma Maandishi** hutambua maandishi kwenye kifaa bila kutuma picha kwa OCR. Huduma za mfumo za utambuzi wa sauti na kusoma kwa sauti ni tofauti: zinaweza kuhitaji mtandao. Kusoma bila mtandao kunahitaji sauti ya nje ya mtandao iliyosakinishwa.
- **Eleza Mazingira** hupiga picha moja na kuomba maelezo.
- **Uliza Swali** hukuruhusu kusema au kuandika swali kuhusu picha mpya.

Ukurasa wa mwanzo una vitufe vya Eleza / Soma / Uliza vyenye lebo na hutumia vidhibiti vya kawaida vya TalkBack, Rudia na Sitisha inayopatikana muda wote. Onyesho la kamera ni la hiari; wasifu wa msaidizi huanza na matokeo ya sauti yamewashwa.

**Mipangilio → Phone & capture guidance** ina ukaguzi wa hiari wa accelerometer/gravity, gyroscope, mwanga na proximity ya mbele. Ukaguzi mfupi unaweza kukuomba ushikilie simu bila mtikisiko, uongeze mwanga au ufunue sensa ya mbele; sensa ikikosekana haizuii picha. Kugundua upatikanaji hakuanzi sampuli. Sampuli ni za muda mfupi kifaani na hazitumwi mtandaoni. Hazipimi umbali wa vizuizi, hazihakikishi fremu ya ukurasa wala kutoa urambazaji. Hakuna GPS wala dira inayotumika.

Eleza na Uliza vinahitaji idhini ya wazi ya AI ya mtandaoni. Hali ya seva hutuma kupitia EyeSense Worker kwa Groq. Kwa ufunguo wako mwenyewe, unachagua Groq, OpenAI, Google Gemini au Mistral ya hiari. Hakuna kubadilisha mtoa huduma kimya kimya. Jaribio la picha iliyotengenezwa linahitaji uthibitisho mwingine na linaweza kutozwa kwenye akaunti yako.

## Hatua rahisi, na msaada ukiuhitaji

1. Kaa au simama bila kusogea ndani ya eneo unalolijua. Fungua EyeSense kwenye simu yako ya Android, au omba msaidizi unayemwamini akusaidie kuisanidi.
2. Chagua **Soma Maandishi**, **Eleza Mazingira** au **Uliza Swali**. OCR ya Soma Maandishi hubaki kifaani; Eleza na Uliza vinahitaji mtandao, ufikiaji wa AI unaofanya kazi na ridhaa yako ya wazi.
3. Sikiliza au soma matokeo. Tumia **Rudia** kusikia tena na **Sitisha** kusimamisha kazi au usemi. Hakiki majibu ya AI; si maelekezo ya kutembea.

Watumiaji wa TalkBack wanaweza kutumia ishara za kawaida za kuchagua na kuamsha vitufe. Wenye uoni hafifu wanaweza kutumia ukubwa wa maandishi/onyesho katika Android. Msaidizi anaweza kuchagua onyesho la kamera, lakini halihitajiki kuanza kazi. Ufikivu bado unahitaji kupimwa kwenye simu halisi kabla ya washiriki.

## Kushiriki majaribio

Majaribio ya watu kumi **yatasimamiwa na bado hayajafunguliwa kwa matumizi ya kujitegemea**. Toleo la debug/test linapatikana hapa chini kwa tathmini ya wasanidi, si uzinduzi rasmi wala idhini ya majaribio. Ufikiaji wa AI na ufikivu kwenye vifaa halisi lazima vithibitishwe kabla ya washiriki. Hakuna fomu ya kujisajili kwenye tovuti hii.

### Pakua toleo la Android la majaribio ya debug

[Pakua EyeSense 1.0.0 debug APK — Android 7.0 au mpya zaidi, 214 MiB](/download/android-debug)

Kiungo hiki kinafungua upakuaji wa toleo kwenye GitHub. **Ni debug iliyosainiwa kwa majaribio, toleo 1.0.0+1; tumia simu ya majaribio na vitu visivyo vya siri.** Hakuna ufunguo wa API wala tokeni ya seva iliyotolewa ndani ya APK. Sanidi muunganisho kwa usalama katika Mipangilio. **Majaribio ya picha ya Groq yalirudisha 403; AI ya mtandaoni haijathibitishwa. TalkBack kwenye simu halisi bado inahitaji kupimwa.** Si ya urambazaji, kutambua vizuizi wala maamuzi ya matibabu.

Soma [maelezo ya toleo la debug na msimbo wake](https://github.com/RealDevRay/eyesense/releases/tag/pilot-debug-2026-10-21) kabla ya kusakinisha. Android inaweza kuomba uruhusu usakinishaji kutoka kivinjari au kidhibiti faili; ruhusu tu ukiamini toleo hili, kisha zima ruhusa hiyo. Usizime ukaguzi wa usalama wa kifaa. Toleo la zamani likiwa na sahihi tofauti, unaweza kuhitaji kuliondoa na kupoteza mipangilio/funguo za kifaani.

[Pakua SHA256SUMS](https://github.com/RealDevRay/eyesense/releases/download/pilot-debug-2026-10-21/SHA256SUMS). SHA-256 ya APK inayotarajiwa:

`bcaaceba730891703102ca2f20008ce9c35f3845d39ec373b6ce18c7b022935a`

Kwa maswali au taarifa zinazofikika, [tuma barua pepe kwa timu ya EyeSense](mailto:info@devray.qzz.io). Usitume funguo za API, picha binafsi, taarifa za matibabu au nyaraka za utambulisho. Barua pepe inashughulikiwa na mtoa huduma wako wa barua pepe; tovuti hii haikusanyi fomu.

## Si nini

EyeSense **si kifaa cha uhamaji, urambazaji au matibabu**. Usiitumie kuamua lini kuvuka barabara, kama njia ni salama, au umbali wa kizuizi. Maelekezo na vichujio vya maneno havihakikishi kuzuia kila jibu lisilo salama.

Tegemea fimbo yako, mbwa kiongozi, mafunzo na busara yako kwa uhamaji, si maelezo ya AI. Soma sehemu ya 2 ya [Masharti ya Matumizi](/sw/terms).

## Faragha, kwa kifupi

Hakuna akaunti za watumiaji, matangazo wala uchanganuzi. Hatutumii maudhui yako kufundisha mifumo; wachakataji waliochaguliwa wana masharti yao ya uchakataji na uhifadhi. **Mistral Free mode inaweza kutumia ingizo na matokeo kufundisha modeli usipojiondoa katika akaunti yako; Free mode haina chaguo la ZDR.** Katika hali ya seva, vihesabu vya maombi vyenye anwani ghafi za IP huhifadhiwa. Madirisha ya dakika moja na nafasi za maombi za sekunde 60 zilizokwisha hufutwa kwa operesheni za baadaye, si kengele ya muda; taarifa zinaweza kubaki huduma ikiwa haitumiki. Funguo za BYOK huhifadhiwa tofauti na hutumwa kwa mtoa huduma aliyechaguliwa pekee.

[Sera ya Faragha](/sw/privacy) inaeleza picha, maswali, huduma za sauti, sensa, funguo, wahusika wengine na uhifadhi. Toleo la **1.1-pilot** linahitaji kuwasha tena ridhaa ya mtandaoni ikiwa toleo lililokubaliwa ni la zamani au halipo. Kukubali masharti pekee hakurudishi ridhaa. OCR ya Soma Maandishi bado inapatikana bila ridhaa ya mtandaoni.

Vikomo vya seva ya majaribio vinavyoshirikiwa ni **maombi 6 kwa dakika, 2 kwa wakati mmoja na 100 kwa siku**. Si mgao wa kila mtu wala ahadi ya uwezo wa bure wa mtoa huduma. Cloudflare inaendesha seva ya kupitisha maombi na kudhibiti matumizi, si uchakataji wa Workers AI.

## Hali

Hii ni programu ya majaribio, si uthibitisho wa utayari wa kutolewa. Vipimo vya kiotomatiki havichukui nafasi ya vipimo vya ufikivu kwenye kifaa halisi. Ombi la jaribio la picha kwa Groq la tarehe 21 Oktoba 2026 lilirudisha HTTP 403; uchakataji wa picha uliofanikiwa bado haujathibitishwa.

Nyaraka hizi zinapatikana pia ndani ya programu, chini ya Mipangilio → Kisheria:

- [Sera ya Faragha](/sw/privacy)
- [Masharti ya Matumizi](/sw/terms)

Tafsiri zinahitaji ukaguzi wa mtaalamu anayejua Kiswahili na sheria. Toleo la Kiingereza ni rejea pale yanapotofautiana.

Maswali au ombi la muundo mwingine wa nyaraka: [info@devray.qzz.io](mailto:info@devray.qzz.io)
