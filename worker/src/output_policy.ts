import { SceneResult } from "./schema";

const PROHIBITED_PHRASES_EN = [
  "safe to cross",
  "clear to cross",
  "cross the road",
  "cross the street",
  "cross now",
  "path is clear",
  "clear path",
  "no hazards present",
  "no hazards",
  "no obstacles",
  "safe to proceed",
  "walk forward",
  "turn left now",
  "turn right now",
  "imminent collision",
  "about to hit",
];

const PROHIBITED_PHRASES_SW = [
  "salama kuvuka",
  "vuka barabara",
  "vuka sasa",
  "njia iko wazi",
  "njia ni wazi",
  "hakuna vikwazo",
  "salama kuendelea",
  "tembea mbele",
  "karibu kugongana",
];

export function containsProhibitedSafetyGuidance(text: string): boolean {
  const lower = text.toLowerCase();
  for (const phrase of PROHIBITED_PHRASES_EN) {
    if (lower.includes(phrase)) return true;
  }
  for (const phrase of PROHIBITED_PHRASES_SW) {
    if (lower.includes(phrase)) return true;
  }
  if (/\b\d+(\.\d+)?\s*(meters?|metres?|feet)\s*away\b/i.test(lower)) {
    return true;
  }
  return false;
}

export function enforceWorkerOutputPolicy(result: SceneResult, language = "en"): SceneResult {
  const isSwahili = language === "sw";
  const limitationSummary = isSwahili
    ? "Picha inaonekana. EyeSense haiwezi kuthibitisha njia salama au kutoa maelekezo ya kuvuka. Tafadhali tumia msaada wako wa kawaida wa uhamaji."
    : "Scene detected. EyeSense cannot confirm navigation safety or crossing decisions. Please rely on your mobility aids and physical orientation.";
  const limitationAnswer = isSwahili
    ? "EyeSense haiwezi kuamua usalama wa njia au kuvuka. Tafadhali tegemea vifaa vyako vya uhamaji."
    : "EyeSense cannot determine path safety or crossing decisions. Please rely on your mobility aids.";
  const limitationNote = isSwahili
    ? "Tahadhari ya usalama: Maelekezo ya kutembea au kuvuka hayawezi kutolewa kutoka kwa picha."
    : "Safety limitation: Walking or crossing guidance cannot be provided from images.";
  const unspecified = isSwahili ? "haijabainishwa" : "unspecified";

  const summaryViolates = containsProhibitedSafetyGuidance(result.summary);
  const answerViolates = result.answer ? containsProhibitedSafetyGuidance(result.answer) : false;
  const concernViolates = result.concernDescription
    ? containsProhibitedSafetyGuidance(result.concernDescription)
    : false;
  const uncertaintyViolates = result.uncertainty ? containsProhibitedSafetyGuidance(result.uncertainty) : false;
  const objects = result.objects.map((object) =>
    containsProhibitedSafetyGuidance(object) ? unspecified : object,
  );
  const objectsChanged = objects.some((object, index) => object !== result.objects[index]);

  if (!summaryViolates && !answerViolates && !concernViolates && !uncertaintyViolates && !objectsChanged) {
    return result;
  }

  return {
    ...result,
    summary: summaryViolates ? limitationSummary : result.summary,
    answer: answerViolates ? limitationAnswer : result.answer,
    concernDescription: concernViolates ? limitationNote : result.concernDescription,
    uncertainty: uncertaintyViolates ? limitationNote : result.uncertainty,
    objects,
    possibleConcern: result.possibleConcern || concernViolates,
  };
}
