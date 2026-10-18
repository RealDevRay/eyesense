import 'package:eyesense/agents/conversation_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const english = <String, String>{
    'describe': 'describe_scene',
    'describe scene': 'describe_scene',
    'describe the scene': 'describe_scene',
    'please describe': 'describe_scene',
    'can you describe the scene': 'describe_scene',
    'what is this': 'describe_scene',
    "what's this": 'describe_scene',
    'what is that': 'describe_scene',
    'read': 'read_text',
    'read text': 'read_text',
    'read this': 'read_text',
    'read this label': 'read_text',
    'read the label': 'read_text',
    'please read this': 'read_text',
    'stop': 'stop',
    'please stop': 'stop',
    'stop now': 'stop',
    'repeat': 'repeat',
    'repeat that': 'repeat',
    'say again': 'repeat',
    'where is the door': 'ask_scene',
    'where is the door?': 'ask_scene',
    'how much is the milk': 'ask_scene',
    'what color is the cup': 'ask_scene',
    'which way is the exit?': 'ask_scene',
    'stop sign': 'clarify',
    'bread': 'clarify',
    'textile': 'clarify',
    'reading lamp': 'clarify',
    'the door is red': 'clarify',
    'a textile sample': 'clarify',
  };

  const swahili = <String, String>{
    'tazama': 'describe_scene',
    'eleza': 'describe_scene',
    'eleza mandhari': 'describe_scene',
    'tafadhali eleza': 'describe_scene',
    'nini hii': 'describe_scene',
    'nini hiki': 'describe_scene',
    'soma': 'read_text',
    'soma maandishi': 'read_text',
    'soma hii': 'read_text',
    'soma lebo': 'read_text',
    'tafadhali soma': 'read_text',
    'soma hii lebo': 'read_text',
    'acha': 'stop',
    'nyamaza': 'stop',
    'simama': 'stop',
    'rudia': 'repeat',
    'rudia tena': 'repeat',
    'sema tena': 'repeat',
    'wapi mlango': 'ask_scene',
    'wapi mlango?': 'ask_scene',
    'vipi bei': 'ask_scene',
    'nani huyo': 'ask_scene',
    'lini duka linafungwa': 'ask_scene',
    'mkate': 'clarify',
    'nguo': 'clarify',
    'barabara': 'clarify',
    'kitabu': 'clarify',
    'mlango': 'clarify',
    'stop sign': 'clarify',
    'textile': 'clarify',
  };

  test('english utterances route without treating lookalikes as commands', () {
    expect(english.length, greaterThanOrEqualTo(30));
    english.forEach((utterance, intent) {
      expect(ConversationAgent.matchIntent(utterance), intent, reason: utterance);
    });
  });

  test('kiswahili utterances route without a cloud fallback for read requests', () {
    expect(swahili.length, greaterThanOrEqualTo(30));
    swahili.forEach((utterance, intent) {
      expect(ConversationAgent.matchIntent(utterance), intent, reason: utterance);
    });
    expect(ConversationAgent.matchIntent('soma hii'), isNot('ask_scene'));
  });
}
