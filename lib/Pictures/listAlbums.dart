import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ms18_applicatie/Pictures/photo_detail_screen.dart';
import '../Pictures/models/category.dart';
import 'package:ms18_applicatie/Pictures/add_picture_screen.dart';
import '../Api/apiManager.dart';
import '../globals.dart';
import '../config.dart' as config;
import '../config.dart';
import '../menu.dart';
import 'package:collection/collection.dart';
import 'models/photo.dart';

class ListAlbums extends StatefulWidget {
  const ListAlbums({super.key});

  @override
  _ListAlbumsState createState() => _ListAlbumsState();
}

class _ListAlbumsState extends State<ListAlbums> {
  String displayedTitle = 'List Albums';
  TextEditingController searchController = TextEditingController();
  List<Category> allCategories = [];
  List<Category> filteredCategories = [];
  List<Photo> albumPhotos = [];
  List<Photo> coverPhotos = [];
  bool isLoading = true;
  String? selectedParentAlbumId;
  List<int> years = [];
  int? selectedSortYear;
  bool editMode = false;

  @override
  void initState() {
    super.initState();
    selectedSortYear = -1;
    fetchAlbums();
    searchController.addListener(onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void onSearchChanged() async {
    setState(() => isLoading = true);
      filteredCategories = filterCategories();
      await fetchCoverPhotos();
    setState(() => isLoading = false);
  }


  List<Category> filterCategories() {
    String query = searchController.text.toLowerCase();
    if(query.isEmpty && selectedSortYear == -1)
      {
        return allCategories.where((cat) => cat.parentAlbumId == currentAlbum?.id).toList();
      }

    return allCategories.where((category) {
      //bool hasNoParentAlbum = category.parentAlbumId == null;
      bool matchesQuery =
          query.isEmpty || category.name.toLowerCase().contains(query);
      bool matchesYear =
          selectedSortYear == -1 || category.year == selectedSortYear;
      return matchesQuery && matchesYear;
    }).toList();
  }

  void fetchAlbums() async {
    setState(() => isLoading = true);
    try {
      final response =
          await ApiManager.get<List<dynamic>>('api/albums', getHeaders());
      final albums =
          response.map((albumJson) => Category.fromJson(albumJson)).toList();

      if (currentAlbum?.id != null) {
        var freshCurrent =
            albums.firstWhereOrNull((album) => album.id == currentAlbum!.id);
        if (freshCurrent != null) {
          currentAlbum = freshCurrent;
        }
      }
      filteredCategories =
          albums.where((cat) => cat.parentAlbumId == currentAlbum?.id).toList();

      albumPhotos = [];
      if (currentAlbum != null &&
          currentAlbum!.photoCount != null &&
          currentAlbum!.photoCount! > 0) {
        fetchAlbumPhotos(currentAlbum!.id);
      }

      coverPhotos = [];
      if (currentAlbum == null ||
          currentAlbum!.photoCount == null ||
          currentAlbum!.photoCount == 0) {
        await fetchCoverPhotos();
      }

      years =
          albums.map((album) => album.year).whereType<int>().toSet().toList();
      years.sort();

      years.insert(0, -1);
      allCategories = albums;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching albums: $e");
      setState(() => isLoading = false);
    }
  }

  String formatTextWithEllipsis(String input, int maxLength) {
    if (input.isEmpty) {
      return input;
    }

    List<String> words = input.split(' ');
    words.forEach((word) {
      if (word.isNotEmpty) {
        words[words.indexOf(word)] =
            word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
    });

    String result = words.join(' ');

    if (result.length > maxLength) {
      result = '${result.substring(0, maxLength - 3)}...';
    }

    return result;
  }

  void showDeleteConfirmationDialog(
      String albumTitle, String albumId, int index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Bevestig Verwijdering',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: <TextSpan>[
                      const TextSpan(text: 'Weet je zeker dat je '),
                      TextSpan(
                          text: formatTextWithEllipsis(albumTitle, 20),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(
                          text: ' en alle onderliggende onderdelen wilt '),
                      const TextSpan(
                          text: 'verwijderen',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: '?'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ja'),
              onPressed: () {
                deleteAlbum(albumId, index);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Nee'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void deleteAlbum(String albumId, int index) async {
    setState(() => isLoading = true);
    try {
      await ApiManager.delete('api/albums/$albumId', getHeaders());

      allCategories.removeWhere((category) =>
          category.id == albumId || category.parentAlbumId == albumId);
      filteredCategories.removeWhere((category) =>
          category.id == albumId || category.parentAlbumId == albumId);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Album successfully deleted")));
    } catch (e) {
      print("Error deleting album: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error deleting album: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _deletePhoto(String photoId, int index) async {
    setState(() => isLoading = true);
    try {
      await ApiManager.delete('api/photos/$photoId', getHeaders());
      setState(() {
        albumPhotos.removeWhere((photo) => photo.id == photoId);
        coverPhotos.removeWhere((photo) => photo.id == photoId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo successfully deleted")));
    } catch (e) {
      print("Error deleting Photo: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error deleting Photo: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void addCategory() {
    TextEditingController nameController = TextEditingController();
    TextEditingController yearController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: 'Name')),
            TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Year (Optional)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              postCategory(nameController.text, yearController.text);
              Navigator.of(context).pop();
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  String formatText(String input) {
    if (input.isEmpty) {
      return input;
    }

    List<String> words = input.split(' ');
    words.forEach((word) {
      if (word.isNotEmpty) {
        words[words.indexOf(word)] =
            word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
    });

    return words.join(' ');
  }

  void postCategory(String name, String year) async {
    try {
      String formattedName = formatText(name);

      Map<String, dynamic> body = {
        'name': formattedName,
      };

      if (year.isNotEmpty) {
        body['year'] = int.tryParse(year);
      }

      if (currentAlbum != null) {
        body['parentAlbumId'] = currentAlbum!.id;
      }

      await ApiManager.post('api/albums', body, getHeaders());
      fetchAlbums(); // Refresh the albums/categories list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category added successfully')),
      );
    } catch (e) {
      print('Error adding category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    }
  }

  void editAlbum(BuildContext context, Category category, int index) {
    TextEditingController nameController =
        TextEditingController(text: category.name);
    TextEditingController yearController =
        TextEditingController(text: category.year?.toString() ?? '');

    String? tempSelectedParentAlbumId = category.parentAlbumId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Album'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(hintText: 'Name')),
                    TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: 'Year (Optional)')),
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Parent Album:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: tempSelectedParentAlbumId,
                      isExpanded: true,
                      hint: Text("Select Parent Album"),
                      onChanged: (value) {
                        setStateDialog(() {
                          tempSelectedParentAlbumId = value;
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("None"),
                        ),
                        ...allCategories
                            .where((c) =>
                                c.id != category.id &&
                                (c.photoCount ?? 0) == 0 &&
                                c.parentAlbumId ==
                                    null) // Alleen parentalbums worden weergegeven
                            .map<DropdownMenuItem<String>>((Category category) {
                          return DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  selectedParentAlbumId = tempSelectedParentAlbumId;
                });
                updateCategory(
                    category.id,
                    nameController.text,
                    yearController.text,
                    tempSelectedParentAlbumId,
                    category.coverPhotoId);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void updateCategory(String id, String name, String year,
      String? parentAlbumId, String? coverPhotoId) async {
    try {
      Map<String, dynamic> body = {'name': name};
      if (year.isNotEmpty) body['year'] = int.tryParse(year);
      if (parentAlbumId != null) body['parentAlbumId'] = parentAlbumId;
      if (coverPhotoId != null) body['coverPhotoId'] = coverPhotoId;

      await ApiManager.put('api/albums/$id', body, getHeaders());

      fetchAlbums();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Album updated successfully')));
    } catch (e) {
      print('Error updating album: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating album: $e')));
    }
  }

  void goBackToParentAlbum() async {
    if (currentAlbum == null) {
      return;
    }

    // If an album is found, set currentAlbum to its parentAlbumId. Otherwise, set currentAlbum to null.
    if (currentAlbum!.parentAlbumId == null) {
      currentAlbum = null;
    } else {
      currentAlbum!.id = currentAlbum!.parentAlbumId!;
    }

    searchController.clear();
    selectedSortYear = -1;
    fetchAlbums();

    // Update the displayed title after the state is updated
    if (currentAlbum != null) {
      setState(() {
        displayedTitle = allCategories
            .firstWhere((category) => category.id == currentAlbum!.id)
            .name;
      });
    } else {
      setState(() {
        displayedTitle = 'List Albums';
      });
    }
  }

  void onAlbumClicked(Category album) async {
    setState(() => isLoading = true);

    searchController.clear();
    selectedSortYear = -1;


    if (album.photoCount! > 0) {
      fetchAlbumPhotos(album.id);
    }
    currentAlbum = album;

    displayedTitle = album.name;
    filteredCategories =
        allCategories.where((cat) => cat.parentAlbumId == album.id).toList();

    await fetchCoverPhotos();

    setState(() => isLoading = false);
  }

  Future<void> fetchCoverPhotos() async {
    List<Photo> tempCoverPhotos =
        []; // Temporary list to store fetched cover photos

    for (Category category in filteredCategories) {
      try {
        final String fetchUrl = 'api/photos/${category.coverPhotoId}';
        final response = await ApiManager.get<dynamic>(fetchUrl, getHeaders());

        if (response is Map<String, dynamic>) {
          Photo coverPhoto = Photo.fromJson(response);
          tempCoverPhotos.add(coverPhoto);
        } else {
          print("Unexpected response format for category ${category.id}");
        }
      } catch (e) {
        print("Error fetching cover photo for category ${category.id}: $e");
      }
    }

    setState(() {
      coverPhotos = tempCoverPhotos;
    });
  }

  void fetchAlbumPhotos(String albumId) async {
    const int pageNumber = 1;
    const int pageSize = 100;
    final String fetchUrl = 'api/photos/album/$albumId?pageNumber=$pageNumber&pageSize=$pageSize';

    try {
      final response = await ApiManager.get<Map<String, dynamic>>(fetchUrl, getHeaders());
      if (response['items'] != null) {
        List<Photo> photos = (response['items'] as List).map((item) => Photo.fromJson(item)).toList();

        // Sort photos by the 'takenOn' field, from the most recent to the oldest
        // Photos with a null 'takenOn' date are placed at the end of the list
        photos.sort((a, b) {
          if (a.takenOn == null && b.takenOn == null) return 0;
          if (a.takenOn == null) return 1;
          if (b.takenOn == null) return -1;
          return b.takenOn!.compareTo(a.takenOn!);
        });

        setState(() {
          albumPhotos = photos;
        });
      }
    } catch (e) {
      print("Error fetching photos: $e");
      setState(() {
        albumPhotos = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showSearchAndYearSelect =
        currentAlbum == null || currentAlbum?.photoCount == 0;

    return Menu(
      title: const Text(
        'Albums',
        style: TextStyle(color: Colors.white),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  displayedTitle,
                  style: currentAlbum == null
                      ? const TextStyle(
                          fontWeight:
                              FontWeight.normal) // Main screen title style
                      : const TextStyle(fontWeight: FontWeight.bold),
                  // Sub-album title style
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (years.isNotEmpty && showSearchAndYearSelect)
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedSortYear,
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                    onChanged: (int? newValue) {
                      setState(() {
                        selectedSortYear = newValue;
                        filteredCategories = filterCategories();
                      });
                    },
                    items: years.map<DropdownMenuItem<int>>((int year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString(),
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          leading: currentAlbum != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: goBackToParentAlbum,
                )
              : null,
        ),
        body: Column(
          children: [
            if (showSearchAndYearSelect)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "Search",
                    hintText: "Search for albums...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25.0)),
                    ),
                  ),
                ),
              ),
            if (years.isNotEmpty && showSearchAndYearSelect) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text("Select Year"),
                  value: selectedSortYear,
                  onChanged: (int? newValue) {
                    setState(() {
                      selectedSortYear = newValue;
                      filteredCategories = filterCategories();
                    });
                  },
                  items: [
                    const DropdownMenuItem<int>(
                      value: -1,
                      child: Text("Alle jaren"),
                    ),
                    ...years
                        .where((year) => year != -1)
                        .map<DropdownMenuItem<int>>((int year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: albumPhotos.isNotEmpty
                          ? albumPhotos.length
                          : filteredCategories.length,
                      itemBuilder: (context, index) {
                        if (albumPhotos.isNotEmpty) {
                          // Displaying photos when an album with photos is selected
                          final photo = albumPhotos[index];
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  // Wait for the PhotoDetailScreen to pop
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PhotoDetailScreen(
                                        photos: albumPhotos,
                                        currentIndex: index,
                                      ),
                                    ),
                                  );
                                  // After returning, refresh the data
                                  fetchAlbums();  // This assumes fetchAlbums fetches and updates the data
                                },
                                child: Image.memory(
                                  base64Decode(photo.imageBase64),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5), // Slightly transparent black
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.favorite, size: 16, color: Colors.red),
                                      SizedBox(width: 4),
                                      Text('${photo.likesCount}', style: const TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                              if (editMode)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black45,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deletePhoto(photo.id!, index),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        } else {
                          final category = filteredCategories[index];
                          Photo? matchingCoverPhoto =
                              coverPhotos.firstWhereOrNull(
                                  (photo) => photo.id == category.coverPhotoId);

                          return GestureDetector(
                            onTap: () => onAlbumClicked(category),
                            child: Stack(
                              children: [
                                category.coverPhotoId != null &&
                                        matchingCoverPhoto != null
                                    ? Image.memory(
                                        base64Decode(
                                            matchingCoverPhoto.imageBase64),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : Image.asset(
                                        'assets/photos/folderIcon.png',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    color: Colors.black.withOpacity(0.7),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: formatTextWithEllipsis(
                                                category.name, 12),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (category.year != null)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: Container(
                                      color: Colors.black.withOpacity(0.7),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 4.0),
                                      child: Text(
                                        category.year.toString(),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Row(
                                    children: [
                                      if (editMode)
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () => editAlbum(
                                              context, category, index),
                                        ),
                                      if (editMode)
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              showDeleteConfirmationDialog(
                                                  category.name,
                                                  category.id,
                                                  index),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (editPermission)
              FloatingActionButton(
                onPressed: () => setState(() => editMode = !editMode),
                heroTag: 'changeEditMode',
                backgroundColor: config.mainColor,
                child: Icon(
                  editMode ? Icons.edit_off : Icons.edit,
                  color: Colors.white,
                ),
              ),
            if (editMode &&
                (currentAlbum == null || currentAlbum!.photoCount == 0))
              FloatingActionButton(
                onPressed: addCategory,
                heroTag: 'addCategoryHeroTag',
                backgroundColor: config.mainColor,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                ),
              ),
            const SizedBox(width: 8.0),
            if (currentAlbum != null &&
                !allCategories
                    .any((cat) => cat.parentAlbumId == currentAlbum!.id))
              FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddPictureScreen()),
                  );
                  fetchAlbums();
                },
                backgroundColor: config.mainColor,
                tooltip: 'Add Photos',
                heroTag: 'addPhotoHeroTag',
                child: const Icon(Icons.photo_camera, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
