package com.urbiztondo.smartflow.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore("smartflow")

class SessionStore(private val context: Context) {
    private val gson = Gson()
    private val tokenKey = stringPreferencesKey("token")
    private val userKey = stringPreferencesKey("user")

    val session: Flow<Pair<String?, UserDto?>> = context.dataStore.data.map { prefs ->
        val token = prefs[tokenKey]
        val userJson = prefs[userKey]
        val user = userJson?.let { gson.fromJson(it, UserDto::class.java) }
        token to user
    }

    suspend fun save(token: String, user: UserDto) {
        ApiClient.token = token
        context.dataStore.edit { prefs ->
            prefs[tokenKey] = token
            prefs[userKey] = gson.toJson(user)
        }
    }

    suspend fun clear() {
        ApiClient.token = null
        context.dataStore.edit { it.clear() }
    }

    suspend fun restoreToken(token: String) {
        ApiClient.token = token
    }
}
