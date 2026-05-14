package com.lampstandhq.introibo.ui.learn

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Multiple-choice quiz generated from flashcard data.
 *
 * Port of iOS Introibo/Screens/Learn/QuizView.swift.
 */

private data class Question(
    val prompt: String,
    val promptLabel: String,
    val correct: String,
    val choices: List<String>,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuizScreen(
    cards: List<Course.Section.Card>,
    lessonTitle: String,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var questionIndex by remember { mutableIntStateOf(0) }
    var score by remember { mutableIntStateOf(0) }
    var selectedAnswer by remember { mutableStateOf<String?>(null) }
    var questions by remember { mutableStateOf<List<Question>>(emptyList()) }
    var isFinished by remember { mutableStateOf(false) }

    fun generateQuestions() {
        val usable = cards.filter { it.lat != null && it.eng != null }
        if (usable.size < 4) return

        val shuffled = usable.shuffled()
        val count = minOf(5, usable.size)
        val qs = mutableListOf<Question>()

        for (i in 0 until count) {
            val card = shuffled[i]
            val cardLat = card.lat ?: continue
            val cardEng = card.eng ?: continue
            val latinToEnglish = listOf(true, false).random()

            if (latinToEnglish) {
                val correct = cardEng
                val wrongs = usable.filter { it.eng != correct }.shuffled().take(3).mapNotNull { it.eng }
                val choices = (wrongs + correct).shuffled()
                qs += Question(prompt = cardLat, promptLabel = "What does this mean?", correct = correct, choices = choices)
            } else {
                val correct = cardLat
                val wrongs = usable.filter { it.lat != correct }.shuffled().take(3).mapNotNull { it.lat }
                val choices = (wrongs + correct).shuffled()
                qs += Question(prompt = cardEng, promptLabel = "What is the Latin?", correct = correct, choices = choices)
            }
        }

        questions = qs
    }

    LaunchedEffect(cards) {
        generateQuestions()
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                TextButton(onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }) {
                    Text("Done", color = colors.sanctuaryRed, style = type.body)
                }
            }

            when {
                isFinished -> {
                    // Finished view
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(text = "✠", style = type.pageTitle.copy(fontSize = 48.sp), color = colors.sanctuaryRed)
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "$score / ${questions.size}",
                            style = type.pageTitle.copy(fontSize = 48.sp),
                            color = colors.primaryText,
                        )
                        Text(
                            text = when {
                                score == questions.size -> "Perfect!"
                                score >= questions.size / 2 -> "Well done"
                                else -> "Keep practising"
                            },
                            style = type.titleM.copy(fontStyle = FontStyle.Italic),
                            color = colors.secondaryText,
                        )
                        Text(
                            text = lessonTitle.uppercase(),
                            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                            color = colors.tertiaryText,
                            letterSpacing = 2.sp,
                        )

                        Spacer(modifier = Modifier.height(20.dp))
                        TextButton(
                            onClick = {
                                questionIndex = 0
                                score = 0
                                selectedAnswer = null
                                isFinished = false
                                generateQuestions()
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 28.dp)
                                .border(0.5.dp, colors.sanctuaryRed.copy(alpha = 0.6f))
                                .padding(vertical = 4.dp),
                        ) {
                            SmallLabel(text = "Try Again", color = colors.sanctuaryRed)
                        }

                        Spacer(modifier = Modifier.height(8.dp))
                        TextButton(onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }) {
                            Text(
                                text = "Done",
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.tertiaryText,
                            )
                        }
                    }
                }
                questions.isNotEmpty() -> {
                    val q = questions[questionIndex]
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(bottom = 40.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(24.dp),
                    ) {
                        Spacer(modifier = Modifier.height(24.dp))
                        SmallLabel(text = "Question ${questionIndex + 1} of ${questions.size}", color = colors.sanctuaryRed)
                        Text(text = "Score: $score", style = type.captionSm, color = colors.goldLeaf)

                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(vertical = 20.dp),
                        ) {
                            SmallLabel(text = q.promptLabel, color = colors.goldLeaf)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = q.prompt,
                                style = type.pageTitle,
                                color = colors.primaryText,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 28.dp),
                            )
                        }

                        Column(
                            modifier = Modifier.padding(horizontal = 28.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            q.choices.forEach { choice ->
                                ChoiceButton(
                                    choice = choice,
                                    correct = q.correct,
                                    selected = selectedAnswer,
                                    onClick = {
                                        if (selectedAnswer == null) {
                                            selectedAnswer = choice
                                            if (choice == q.correct) score++
                                        }
                                    },
                                )
                            }
                        }

                        if (selectedAnswer != null) {
                            TextButton(
                                onClick = {
                                    if (questionIndex + 1 < questions.size) {
                                        questionIndex++
                                        selectedAnswer = null
                                    } else {
                                        isFinished = true
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 28.dp)
                                    .border(0.5.dp, colors.sanctuaryRed.copy(alpha = 0.6f))
                                    .padding(vertical = 4.dp),
                            ) {
                                SmallLabel(
                                    text = if (questionIndex + 1 < questions.size) "Next" else "See Results",
                                    color = colors.sanctuaryRed,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChoiceButton(
    choice: String,
    correct: String,
    selected: String?,
    onClick: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val hasAnswered = selected != null
    val isSelected = selected == choice
    val isCorrect = choice == correct

    val bgColor = when {
        !hasAnswered -> colors.pageBackground
        isCorrect -> Color(0xFF4CAF50).copy(alpha = 0.1f)
        isSelected && !isCorrect -> colors.sanctuaryRed.copy(alpha = 0.1f)
        else -> colors.pageBackground
    }

    val borderColor = when {
        !hasAnswered -> colors.frameLine
        isCorrect -> Color(0xFF4CAF50).copy(alpha = 0.6f)
        isSelected && !isCorrect -> colors.sanctuaryRed.copy(alpha = 0.6f)
        else -> colors.frameLine
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .border(0.5.dp, borderColor, RoundedCornerShape(6.dp))
            .clickable(enabled = !hasAnswered) { onClick() }
            .padding(vertical = 14.dp, horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = choice,
            style = type.body,
            color = colors.primaryText,
            modifier = Modifier.weight(1f),
        )
        if (hasAnswered && isCorrect) {
            Text(text = "✓", color = Color(0xFF4CAF50), style = type.titleM)
        } else if (hasAnswered && isSelected && !isCorrect) {
            Text(text = "✗", color = colors.sanctuaryRed, style = type.titleM)
        }
    }
}
