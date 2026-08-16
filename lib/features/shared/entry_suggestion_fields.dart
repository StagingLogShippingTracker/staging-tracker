import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/person_name_memory.dart';
import '../../data/remembered_contacts.dart';
import '../../domain/models.dart';

enum RememberedEntryKind { customer, person }

class RememberedEntryField extends ConsumerStatefulWidget {
  const RememberedEntryField({
    super.key,
    required this.controller,
    required this.kind,
    required this.label,
  });

  final TextEditingController controller;
  final RememberedEntryKind kind;
  final String label;

  @override
  ConsumerState<RememberedEntryField> createState() =>
      _RememberedEntryFieldState();
}

class _RememberedEntryFieldState extends ConsumerState<RememberedEntryField> {
  final _focusNode = FocusNode();
  final _hiddenLocal = <String>{};

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isHidden(String value) =>
      _hiddenLocal.contains(value.trim().toLowerCase());

  Future<void> _hide(String value) async {
    final key = value.trim().toLowerCase();
    if (key.isEmpty) return;
    setState(() => _hiddenLocal.add(key));
    await hideRememberedMemory(ref, value);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.kind == RememberedEntryKind.customer
        ? ref.watch(customerSuggestionsProvider).valueOrNull ?? const <String>[]
        : ref.watch(personNameMemoryProvider).names;
    final noun = widget.kind == RememberedEntryKind.customer
        ? 'customer'
        : widget.label.toLowerCase();
    final icon = widget.kind == RememberedEntryKind.customer
        ? Icons.business_outlined
        : Icons.person_outline;

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          final visible = suggestions.where((s) => !_isHidden(s));
          if (query.isEmpty) return visible;
          return visible.where(
            (suggestion) => suggestion.toLowerCase().contains(query),
          );
        },
        onSelected: (value) {
          widget.controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: 'Select a remembered $noun or type a new one',
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            onSubmitted: (_) => onSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final visible = options.where((s) => !_isHidden(s)).take(30).toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                  maxHeight: 260,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final suggestion = visible[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(icon),
                      title: Text(
                        suggestion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Forget this value',
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () => _hide(suggestion),
                      ),
                      onTap: () => onSelected(suggestion),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CustomerSuggestionField extends StatelessWidget {
  const CustomerSuggestionField({
    super.key,
    required this.controller,
    this.label = 'Customer',
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => RememberedEntryField(
    controller: controller,
    kind: RememberedEntryKind.customer,
    label: label,
  );
}

class PersonSuggestionField extends ConsumerStatefulWidget {
  const PersonSuggestionField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText = 'Type a name or pick from shared memory',
  });

  final TextEditingController controller;
  final String label;
  final String hintText;

  @override
  ConsumerState<PersonSuggestionField> createState() =>
      _PersonSuggestionFieldState();
}

class _PersonSuggestionFieldState extends ConsumerState<PersonSuggestionField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) return;
    ref.read(personNameMemoryProvider.notifier).sync(forceRefresh: true);
    final names = ref.read(personNameMemoryProvider).names;
    if (names.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = widget.controller.text;
      widget.controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    });
  }

  Future<void> _commit(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    await ref.read(personNameMemoryProvider.notifier).remember(name);
  }

  Future<void> _forget(String name) async {
    final message =
        await ref.read(personNameMemoryProvider.notifier).forget(name);
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(personNameMemoryProvider);
    final remembered = memory.rememberedKeys;

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        key: ValueKey(
          'person-ac-${memory.names.length}-${remembered.length}-'
          '${widget.label}',
        ),
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value) =>
            filterPersonNames(memory.names, value.text),
        displayStringForOption: (n) => n,
        onSelected: (n) {
          widget.controller.value = TextEditingValue(
            text: n,
            selection: TextSelection.collapsed(offset: n.length),
          );
          _commit(n);
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (value) {
              onSubmitted();
              _commit(value);
            },
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: memory.loading
                  ? 'Loading directory…'
                  : widget.hintText,
              helperText: 'Shared across devices',
              suffixIcon: memory.loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (memory.names.isEmpty
                      ? IconButton(
                          tooltip: 'Refresh directory',
                          onPressed: () => ref
                              .read(personNameMemoryProvider.notifier)
                              .sync(forceRefresh: true),
                          icon: const Icon(Icons.refresh, size: 18),
                        )
                      : Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).hintColor,
                        )),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final opts = options.toList(growable: false);
          if (opts.isEmpty) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 260,
                  maxWidth: constraints.maxWidth,
                  minWidth: 220,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: opts.length,
                  itemBuilder: (context, i) {
                    final name = opts[i];
                    final isRemembered =
                        remembered.contains(name.trim().toLowerCase());
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: isRemembered
                          ? const Text(
                              'Shared across devices',
                              style: TextStyle(fontSize: 11),
                            )
                          : null,
                      onTap: () => onSelected(name),
                      trailing: isRemembered
                          ? IconButton(
                              tooltip: 'Remove from shared memory',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _forget(name),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ContactEmailField extends ConsumerStatefulWidget {
  const ContactEmailField({
    super.key,
    required this.controller,
    this.label = 'PM email',
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final bool optional;

  @override
  ConsumerState<ContactEmailField> createState() => _ContactEmailFieldState();
}

class _ContactEmailFieldState extends ConsumerState<ContactEmailField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider).valueOrNull ?? const [];
    final emailContacts =
        contacts.where((contact) => _isEmail(contact.email)).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<ContactPerson>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        displayStringForOption: (contact) => contact.email,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return emailContacts;
          return emailContacts.where((contact) {
            final identity =
                '${contact.name} ${contact.designation} ${contact.email} '
                        '${contact.branch}'
                    .toLowerCase();
            return identity.contains(query);
          });
        },
        onSelected: (contact) {
          widget.controller.value = TextEditingValue(
            text: contact.email,
            selection: TextSelection.collapsed(offset: contact.email.length),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: widget.optional
                  ? '${widget.label} (optional)'
                  : widget.label,
              helperText: 'Search contacts by name, role, branch, or email',
              suffixIcon: const Icon(Icons.contact_mail_outlined),
            ),
            onSubmitted: (_) => onSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final visible = options.take(30).toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                  maxHeight: 300,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final contact = visible[index];
                    return InkWell(
                      onTap: () => onSelected(contact),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              contact.designation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              contact.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CarrierSuggestionField extends ConsumerStatefulWidget {
  const CarrierSuggestionField({
    super.key,
    required this.controller,
    this.label = 'Carrier',
  });

  final TextEditingController controller;
  final String label;

  @override
  ConsumerState<CarrierSuggestionField> createState() =>
      _CarrierSuggestionFieldState();
}

class _CarrierSuggestionFieldState
    extends ConsumerState<CarrierSuggestionField> {
  final _focusNode = FocusNode();
  final _hiddenLocal = <String>{};

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isHidden(String value) =>
      _hiddenLocal.contains(value.trim().toLowerCase());

  Future<void> _hide(String value) async {
    final key = value.trim().toLowerCase();
    if (key.isEmpty) return;
    setState(() => _hiddenLocal.add(key));
    await hideRememberedMemory(ref, value);
  }

  @override
  Widget build(BuildContext context) {
    final carriers =
        ref.watch(carrierSuggestionsProvider).valueOrNull ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          final visible = carriers.where((c) => !_isHidden(c));
          if (query.isEmpty) return visible;
          return visible.where(
            (carrier) => carrier.toLowerCase().contains(query),
          );
        },
        onSelected: (carrier) {
          widget.controller.value = TextEditingValue(
            text: carrier,
            selection: TextSelection.collapsed(offset: carrier.length),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: 'Select a remembered carrier or type a new one',
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            onSubmitted: (_) => onSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final visible = options.where((c) => !_isHidden(c)).take(30).toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                  maxHeight: 260,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final carrier = visible[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        carrier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Forget this value',
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () => _hide(carrier),
                      ),
                      onTap: () => onSelected(carrier),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

bool _isEmail(String value) {
  final email = value.trim();
  return email.contains('@') && email.contains('.');
}
