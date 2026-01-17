import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/class_model.dart';
import '../../models/student_model.dart';
import '../../services/http_data_service.dart';

class ClassEditPage extends StatefulWidget {
  final ClassModel classModel;
  const ClassEditPage({super.key, required this.classModel});

  @override
  State<ClassEditPage> createState() => _ClassEditPageState();
}

class _ClassEditPageState extends State<ClassEditPage> {
  late List<StudentModel> _localStudents;

  @override
  void initState() {
    super.initState();
    _localStudents = List<StudentModel>.from(widget.classModel.students);
  }

  Future<void> _showStudentDialog({StudentModel? existing}) async {
    final rollController = TextEditingController(text: existing?.rno ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final photoController =
        TextEditingController(text: existing?.photoUrl ?? '');

    final isEditing = existing != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickImage(ImageSource source) async {
              final picker = ImagePicker();
              final XFile? picked =
                  await picker.pickImage(source: source, imageQuality: 85);
              if (picked != null) {
                setLocalState(() {
                  photoController.text = picked.path;
                });
              }
            }

            Future<void> showPickerSheet() async {
              await showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from Gallery'),
                          onTap: () async {
                            Navigator.pop(context);
                            await pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_camera),
                          title: const Text('Take a Photo'),
                          onTap: () async {
                            Navigator.pop(context);
                            await pickImage(ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit Student' : 'Add Student'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: showPickerSheet,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            child: (photoController.text.isNotEmpty &&
                                    photoController.text.startsWith('http'))
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: photoController.text,
                                      imageBuilder: (context, imageProvider) =>
                                          Image(
                                        image: imageProvider,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                      placeholder: (context, url) => Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey.shade200,
                                        child:
                                            const Icon(Icons.person, size: 36),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.person, size: 36),
                                    ),
                                  )
                                : const Icon(Icons.person, size: 36),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.photo_camera,
                                size: 18, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rollController,
                      decoration:
                          const InputDecoration(labelText: 'Roll Number'),
                      enabled: !isEditing, // don't allow changing primary key
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (rollController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final data = context.read<HttpDataService>();
      final updated = StudentModel(
        rno: rollController.text.trim(),
        name: nameController.text.trim(),
        photoUrl: photoController.text.trim(),
      );
      if (isEditing) {
        await data.updateStudentInClass(
          widget.classModel.docId!,
          updated,
        );
        setState(() {
          _localStudents = _localStudents
              .map((s) => s.rno == updated.rno ? updated : s)
              .toList();
        });
      } else {
        await data.addStudentToClass(
          widget.classModel.docId!,
          updated,
        );
        setState(() {
          _localStudents = List.from(_localStudents)..add(updated);
        });
      }
    }
  }

  Future<void> _removeStudent(String roll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Are you sure you want to remove roll $roll?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _localStudents.removeWhere((s) => s.rno == roll);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from view only (not saved to server).'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final freshClass = widget.classModel;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Student List',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${freshClass.name} | Code: ${freshClass.id} | Section: ${freshClass.section}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _localStudents.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final s = _localStudents[index];
          return ListTile(
            leading: CircleAvatar(
              child: (s.photoUrl.isNotEmpty && s.photoUrl.startsWith('http'))
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: s.photoUrl,
                        cacheManager: null,
                        imageBuilder: (context, imageProvider) => Image(
                          image: imageProvider,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                        placeholder: (context, url) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Text(s.name.isNotEmpty
                              ? s.name[0].toUpperCase()
                              : '?'),
                        ),
                      ),
                    )
                  : Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?'),
            ),
            title: Text('${s.name}'),
            subtitle: Text('Roll: ${s.rno}'),
            contentPadding: const EdgeInsets.only(left: 12, right: 4),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _showStudentDialog(existing: s),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _removeStudent(s.rno),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
