import { processConversationRequest } from "./conversation";
import { processReadingRequest } from "./reading";
import { processVisionRequest } from "../vision";

export const AgentDispatch = {
  processVision: processVisionRequest,
  processReading: processReadingRequest,
  processConversation: processConversationRequest,
};
