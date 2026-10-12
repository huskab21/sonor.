import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';
import 'sound_engine_stub.dart' if (dart.library.ffi) 'sound_engine.dart';
import 'transcriber.dart';

/// Дохионы хэлээр хариулах «Sign Bridge» аппыг нээх холбоос. ТААМАГ: жинхэнэ холбоосыг
/// (URL scheme) аппын хөгжүүлэгчээс аваад энд солино.
const String signBridgeUrl = 'signbridge://';

/// Яриагаар солилцсон нэг мөр: бусдын хэлсэн (бичвэр болгосон) эсвэл миний бичсэн.
class WorkspaceMessage {
  WorkspaceMessage(this.text, {required this.mine}) : time = DateTime.now();
  final String text;
  final bool mine;
  final DateTime time;
}

/// Ажлын байрны харилцаа: хажуугийн хүний яриаг бичвэр болгож харуулна, хариугаа бичээд
/// том үсгээр үзүүлнэ. Яваандаа байгууллагын чатбот энд нэмэгдэнэ.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.engine,
    required this.messages,
    this.transcriber,
  });
  final SoundEngine engine;

  /// Хуудас солигдоход алга болохгүйн тулд жагсаалтыг эзэн дэлгэц хадгална.
  final List<WorkspaceMessage> messages;
  final Transcriber? transcriber;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const int _maxSeconds = 60;
  late final Transcriber _transcriber = widget.transcriber ?? Transcriber();
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _recording = false;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    if (_recording) widget.engine.stopSample();
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _add(WorkspaceMessage message) {
    setState(() => widget.messages.add(message));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _listen() async {
    if (_recording) {
      widget.engine.stopSample();
      return;
    }
    if (_working) return;
    setState(() {
      _recording = true;
      _error = null;
    });
    final recorded = await widget.engine.recordClip(maxSeconds: _maxSeconds);
    if (!mounted) return;
    final clip = recorded.clip;
    if (clip == null) {
      setState(() {
        _recording = false;
        _error = recorded.error;
      });
      return;
    }
    setState(() {
      _recording = false;
      _working = true;
    });
    final result = await _transcriber.transcribe(clip);
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = result.error;
    });
    final text = result.text;
    if (text != null) _add(WorkspaceMessage(text, mine: false));
  }

  void _send() {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    _reply.clear();
    _add(WorkspaceMessage(text, mine: true));
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _bubble(BuildContext context, WorkspaceMessage m) {
    final ink = inkOf(context);
    final paper = Theme.of(context).colorScheme.surface;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          // Миний бичсэн нь урвуу өнгөтэй: хажуугийн хүнд уншихад тод
          color: m.mine ? ink : ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  m.mine ? Icons.keyboard : Icons.record_voice_over,
                  size: 14,
                  color: (m.mine ? paper : ink).withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  '${m.mine ? 'Би' : 'Яриа'} · ${_clock(m.time)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: (m.mine ? paper : ink).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.text,
              style: TextStyle(
                fontSize: m.mine ? 24 : 20,
                height: 1.3,
                fontWeight: m.mine ? FontWeight.w600 : FontWeight.w400,
                color: m.mine ? paper : ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sign Bridge апп руу үсэрнэ. Суугаагүй бол мэдэгдэнэ.
  Future<void> _openSignBridge() async {
    var opened = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        opened =
            await const MethodChannel('sonor/device')
                .invokeMethod<bool>('openUrl', {'url': signBridgeUrl}) ??
            false;
      } catch (_) {
        // Нээж чадаагүй: доорх мэдэгдэл гарна
      }
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign Bridge апп энэ утсанд суугаагүй байна.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    final messages = widget.messages;
    final status = _recording
        ? 'Сонсож байна… дуусмагц дахин дарна'
        : _working
        ? 'Бичвэр болгож байна…'
        : _error;
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Workspace'),
          backgroundColor: Colors.transparent,
          actions: [
            if (messages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Яриаг цэвэрлэх',
                onPressed: () => setState(messages.clear),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Text(
                            _transcriber.available
                                ? 'Доорх товчийг дараад хажуугийн хүнээ яриулна.\n'
                                      'Хэлсэн үг нь энд бичвэрээр гарна.\n\n'
                                      'Хариугаа доор бичвэл том үсгээр харагдана.'
                                : 'Яриа таних үйлчилгээ хараахан холбогдоогүй байна.\n\n'
                                      'Хариугаа доор бичиж хажуугийн хүндээ үзүүлж болно.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: faint, height: 1.5),
                          ),
                        )
                      : ListView(
                          controller: _scroll,
                          children: [
                            for (final m in messages) _bubble(context, m),
                          ],
                        ),
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _recording || _working ? null : urgentAmber,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _working ? null : _listen,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _recording ? 'Зогсоох' : 'Яриаг бичвэр болгох',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: 10),
                Glass(
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Хариу бичих',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: 'Харуулах',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openSignBridge,
                  icon: const Icon(Icons.sign_language),
                  label: const Text('Sign Bridge-ээр хариулах'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Яриа таних үед бичлэг Chimege-ийн сервер рүү илгээгдэнэ. Ярих хүндээ урьдчилж хэлээрэй.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: faint, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
