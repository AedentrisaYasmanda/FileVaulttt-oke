import HashMap "mo:map/Map";
import Vector "mo:vector";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import { phash } "mo:map/Map";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Int "mo:base/Int";
import IC "ic:aaaaa-aa";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";

persistent actor AnonymousPost {

    // defining comment type
    type PostComment = {
      authorAlias: Text;
      commentText: Text;
      date: Text;
    };

    type PostData = {
        id : Nat;
        title : Text;
        authorAlias : Text;
        postText : Text;
        date : Text;
        comments: [PostComment];// new field to store comment
    };

    type AnonymousPost = {
        user : Principal;
        postData : PostData;
    };

    type PostResponse = {
      status: Text;
      message: Text;
    };

    type UserPosts = HashMap.Map<Principal, [AnonymousPost]>;

    private let usersPosts = HashMap.new<Principal, [AnonymousPost]>();
    
    private let usedIds = HashMap.new<Nat, ()>();
    
    private let postsBank = Vector.new<AnonymousPost>();

    func natHash(n: Nat): Nat32 {
      Nat32.fromNat(n)
    };

    func natEqual(a: Nat, b: Nat): Bool {
      a == b
    };
    
    func blobToNat(blob : Blob) : Nat {
      let bytes = Blob.toArray(blob);
      let limitedSize = if (bytes.size() >= 4) 4 else bytes.size();
      var result : Nat = 0;

      for (i in Iter.range(0, limitedSize - 1)) {
        result := result * 256 + Nat8.toNat(bytes[i]);
      };

      result;
    };

    // Async recursive function dibuat sebagai fungsi private tersendiri
    private func tryGenerate() : async Nat {
      let randBlob = await IC.raw_rand();
      let newId = blobToNat(randBlob);
      let exists = HashMap.get(usedIds, (natHash, natEqual), newId);
      if (exists == null) {
        ignore HashMap.put(usedIds, (natHash, natEqual), newId, ());
        return newId;
      } else {
        return await tryGenerate(); // rekursif jika id sudah pernah digunakan
      };
    };

    public shared func generateUniqueId() : async Nat {
      await tryGenerate();
    };

    public shared func getAllPosts(offset: Nat, length: Nat) : async [AnonymousPost] {
        let newVec = Vector.toArray(
            postsBank
        );

        try {
          var mutLength = length;
          var mutOffset = offset;

          if(mutLength > 10) {
            mutLength := 10;
          };

          let currVecSize: Nat = Array.size(newVec);

          if(mutOffset >= currVecSize) {
              mutOffset := 0;
          };

          var totalLength: Nat = mutLength + mutOffset;
          

          if(totalLength > currVecSize) {
            mutLength := currVecSize - mutOffset;
          };

          Array.subArray(newVec, mutOffset, mutLength);
          
        } catch(_) {

          let emptyArr = Vector.new<AnonymousPost>();
          Vector.toArray<AnonymousPost>(emptyArr);
        }
    };

    public shared(msg) func getCurrUserPosts() : async [AnonymousPost] {
      switch(HashMap.get(usersPosts, phash, msg.caller)) {
        case null [];
        case (?currUserPosts) {
          currUserPosts;
        }
      }
    };

    public shared(msg) func addPost(
      title : Text,
      authorAlias : Text,
      postText : Text,
      date : Text,
      comments : [PostComment]
    ) : async PostResponse {

      if (Text.size(postText) == 0 or Text.size(title) == 0) {
        return {
          status = "error";
          message = "Judul dan isi post tidak boleh kosong.";
        };
      };
      
      if (Text.size(postText) > 280) {
        return {
          status = "error";
          message = "Post terlalu panjang. Maksimal 280 karakter.";
        };
      };

      let newId = await generateUniqueId();

      let postData = {
        id = newId;
        title = title;
        authorAlias = authorAlias;
        postText = postText;
        date = date;
        comments = [];
      };

      let anonymousPost = {
        user = msg.caller;
        postData = postData;
      };

      let _ = Vector.add(postsBank, anonymousPost);

      switch(HashMap.get(usersPosts, phash, msg.caller)) {
        case null {
          
          let vecPost = Vector.new<AnonymousPost>();
          Vector.add(vecPost, anonymousPost);

          let _ = HashMap.put<Principal, [AnonymousPost]>(
            usersPosts, 
            phash, 
            msg.caller, 
            Vector.toArray(vecPost)
          );
        };
        case(?currUserPosts) {
          let newVec = Vector.fromArray<AnonymousPost>(currUserPosts);
          Vector.add<AnonymousPost>(newVec, anonymousPost);
          
          let _ = HashMap.put<Principal, [AnonymousPost]>(
            usersPosts, 
            phash, 
            msg.caller, 
            Vector.toArray<AnonymousPost>(newVec)
          );
        }
      };

      return {
        status = "success";
        message = "Post berhasil ditambahkan!";
      };
    };

    public shared query func searchPost(keyword: Text) : async [AnonymousPost] {
      let lowerKeyword = Text.toLowercase(keyword);
      let postArray = Vector.toArray(postsBank);

      let result = Array.filter<AnonymousPost>(
        postArray,
        func (post: AnonymousPost) : Bool {
          let titleLower = Text.toLowercase(post.postData.title);
          let aliasLower = Text.toLowercase(post.postData.authorAlias);

          Text.contains(titleLower, #text lowerKeyword) or
          Text.contains(aliasLower, #text lowerKeyword)
        }
      );

      result;
    };

    // Function to get a post and add a comment
    public shared func addComment(postId: Text, authorAlias: Text, commentText: Text, date: Text) : async Text {
        let allPosts = await getAllPosts(0, 100); // await to call function getAllPosts

        let idAsNat : Nat = switch (Nat.fromText(postId)) {
            case (?n) n;
            case (null) return "404 Page Not Found";// Handle invalid input
        };

        for (post in allPosts.vals()) {
            if (post.postData.id == idAsNat) {// Compare Nat with Nat
                // input for comment
                let newComment: PostComment = {
                    authorAlias = authorAlias;
                    commentText = commentText;
                    date = date;
                };

                // update comment content in the PostData
                let updatedPost = {
                    id = post.postData.id;
                    title = post.postData.title;
                    authorAlias = post.postData.authorAlias;
                    postText = post.postData.postText;
                    date = post.postData.date;
                    comments = Array.append(post.postData.comments, [newComment]); // Append comments
                };

                // find index in the allposts position
                var index : ?Nat = null;//if matching post is found, index will store the position of that post
                var i = 0;
                while (i < Array.size(allPosts) and index == null) {
                    if (allPosts[i].postData.id == idAsNat) {
                        index := ?i;
                    };
                    i += 1;
                };
                
                // switch case for index
                switch (index) {
                    case (?i) {
                        // Replace the post in postsBank
                        let _ = Vector.put(postsBank, i, { user = post.user; postData = updatedPost });
                        return "Comment submitted!";
                    };
                    case null {
                        return "Post not found.";
                    };
                };
            };
        };
        return "Post not found.";
    };

    public shared func selectPost(postId: Text) : async ?PostData {
        let allPosts = await getAllPosts(0, 100); // await to call function getAllPosts

        let idAsNat : Nat = switch (Nat.fromText(postId)) {
            case (?n) n;
            case (null) return null; // Handle invalid input
        };

        for (post in allPosts.vals()) {  // Correct iteration
            if (post.postData.id == idAsNat) { // Compare Nat with Nat
                return ?post.postData; // Return correct type
            };
        };

        return null;
    };
};