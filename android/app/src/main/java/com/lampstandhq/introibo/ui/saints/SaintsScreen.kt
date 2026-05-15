package com.lampstandhq.introibo.ui.saints

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Saints browser. Shows all saints as cards; tapping opens detail.
 *
 * Port of iOS Introibo/Screens/Saints/SaintsView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SaintsScreen(
    onBack: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val context = LocalContext.current
    val progressRepo = remember { UserProgressRepository(context) }
    val followedSlug by progressRepo.followedSaint.collectAsState(initial = null)

    var selection by remember { mutableStateOf<Saint?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Praxes Sanctórum", style = type.titleM, color = colors.primaryText) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.pageBackground),
            )
        },
        containerColor = colors.pageBackground,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            ContentStore.saints.forEach { saint ->
                SaintCard(
                    saint = saint,
                    isFollowed = saint.slug == followedSlug,
                    onClick = { selection = saint },
                )
            }
        }
    }

    selection?.let { saint ->
        SaintDetailScreen(
            saint = saint,
            onDismiss = { selection = null },
        )
    }
}

@Composable
private fun SaintCard(
    saint: Saint,
    isFollowed: Boolean,
    onClick: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .clickable { onClick() }
            .padding(16.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = saint.name,
                style = type.titleL.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
                modifier = Modifier.weight(1f),
            )
            if (isFollowed) {
                SmallLabel(text = "Following", color = colors.goldLeaf)
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = saint.title,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
        )
        Text(
            text = saint.quote,
            style = type.bodyIt,
            color = colors.tertiaryText,
            lineHeight = type.bodyIt.fontSize * 1.2f,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}
