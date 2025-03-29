import { AuthClient } from "@dfinity/auth-client";
import { createActor } from "declarations/backend";
import { canisterId } from "declarations/backend/index.js";
import React, { useState, useEffect } from "react";
import "../index.css";

const network = process.env.DFX_NETWORK;
const identityProvider =
  network === "ic"
    ? "https://identity.ic0.app" // Mainnet
    : "http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:4943"; // Local

function App() {
  const [authMode, setAuthMode] = useState(0); // 0: initial, 1: user, 2: guest
  const [authClient, setAuthClient] = useState();
  const [posts, setPosts] = useState([]); // State for posts
  const [loading, setLoading] = useState(false); // Loading state

  useEffect(() => {
    initializeAuthClient();
    if (authMode === 1) {
      fetchPosts(); // Fetch posts when user is authenticated
    }
  }, [authMode]);

  async function initializeAuthClient() {
    const client = await AuthClient.create();
    setAuthClient(client);
    const isAuthenticated = await client.isAuthenticated();
    setAuthMode(isAuthenticated ? 1 : 0);
  }

  async function login() {
    await authClient.login({
      identityProvider,
      onSuccess: () => {
        setAuthMode(1); // User logged in
        initializeAuthClient();
      },
    });
  }

  function loginAsGuest() {
    setAuthMode(2); // Guest logged in
  }

  async function logout() {
    if (authMode === 1) {
      await authClient.logout();
    }
    setAuthMode(0); // Reset to initial mode
  }

  async function fetchPosts() {
  setLoading(true);
  try {
    const actor = createActor(canisterId, {
      agentOptions: {
        identity: await authClient.getIdentity(),
      },
    });
    const result = await actor.getAllPosts(0, 10); 
    console.log("Fetched posts:", result);

    // Map and format the data
    const mappedPosts = result.map((post) => ({
      id: post.postData.id,
      title: post.postData.title,
      postText: post.postData.postText,
      date: post.postData.date,
      authorAlias: post.postData.authorAlias,
    }));

    setPosts(mappedPosts);
  } catch (error) {
    console.error("Error fetching posts:", error);
  } finally {
    setLoading(false);
  }
}


  return (
    <div className="container mx-auto p-4">
      <h1 className="mb-6 text-2xl font-bold text-center">Spill r</h1>

      {authMode === 0 && (
        <div className="flex flex-col items-center space-y-4">
          <button
            onClick={login}
            className="rounded bg-blue-500 px-4 py-2 text-white hover:bg-blue-600"
          >
            Login with Internet Identity
          </button>
          <button
            onClick={loginAsGuest}
            className="rounded bg-gray-500 px-4 py-2 text-white hover:bg-gray-600"
          >
            Login as Guest
          </button>
        </div>
      )}

      {authMode === 1 && (
        <div className="text-center">
          <h2 className="mb-4 text-xl font-semibold">Welcome, User!</h2>
          <button
            onClick={logout}
            className="rounded bg-red-500 px-4 py-2 text-white hover:bg-red-600"
          >
            Logout
          </button>

          {loading ? (
            <p>Loading posts...</p>
          ) : (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            {posts.map((post) => (
              <div key={post.id} className="rounded-lg border p-4 shadow">
                <h3 className="text-lg font-bold">{post.title}</h3>
                <p className="text-sm text-gray-500">
                  By {post.authorAlias} on {post.date}
                </p>
                <p className="mt-2">{post.postText}</p>
              </div>
            ))}
          </div>

          )}
        </div>
      )}

      {authMode === 2 && (
        <div className="text-center">
          <h2 className="mb-4 text-xl font-semibold">Welcome, Guest!</h2>
          <button
            onClick={logout}
            className="rounded bg-red-500 px-4 py-2 text-white hover:bg-red-600"
          >
            Logout
          </button>
        </div>
      )}
    </div>
  );
}

export default App;
