enum AssistantAction {
  describe,
  read,
  repeat,
  stop,
  location,
  navigate,
  help,
  unknown,
}

class AssistantCommand {
  const AssistantCommand(this.action, [this.query = '']);
  final AssistantAction action;
  final String query;
  static AssistantCommand parse(String input) {
    final t = input.toLowerCase().trim();
    if (RegExp(r'^(стоп|останов|замолчи|тоқта)').hasMatch(t))
      return const AssistantCommand(AssistantAction.stop);
    if (RegExp(r'повтори|қайтала').hasMatch(t))
      return const AssistantCommand(AssistantAction.repeat);
    if (RegExp(r'прочитай|читать|текст|мәтін|оқып').hasMatch(t))
      return const AssistantCommand(AssistantAction.read);
    if (RegExp(r'что перед|что вокруг|опиши|обстановк|сипатта|не бар')
        .hasMatch(t))
      return const AssistantCommand(AssistantAction.describe);
    if (RegExp(r'где я|моё мест|мое мест|қайдамын').hasMatch(t))
      return const AssistantCommand(AssistantAction.location);
    final match = RegExp(
      r'^(?:маршрут до|построй маршрут до|проведи до|отведи в|пойти в|иди до|найди|барғым келеді)\s+(.+)$',
    ).firstMatch(t);
    if (match != null)
      return AssistantCommand(AssistantAction.navigate, match.group(1)!);
    if (RegExp(r'помощь|что умеешь|көмек').hasMatch(t))
      return const AssistantCommand(AssistantAction.help);
    return const AssistantCommand(AssistantAction.unknown);
  }
}
