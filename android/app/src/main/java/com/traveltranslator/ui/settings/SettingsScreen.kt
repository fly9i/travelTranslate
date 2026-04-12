package com.traveltranslator.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.traveltranslator.BuildConfig
import com.traveltranslator.domain.model.Destinations

/** 设置页。 */
@Composable
fun SettingsScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("设置", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("后端服务：${BuildConfig.API_BASE_URL}")
        Text("支持的目的地：${Destinations.all.joinToString { "${it.flag} ${it.name}" }}")
        Spacer(Modifier.height(8.dp))
        Button(onClick = { /* TODO: 下载离线包 */ }, modifier = Modifier.fillMaxWidth()) {
            Text("下载/更新离线短语包")
        }
    }
}
