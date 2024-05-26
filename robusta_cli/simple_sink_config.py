from pydantic import BaseModel

# from robusta.core.sinks.msteams.msteams_sink_params import MsTeamsSinkConfigWrapper, MsTeamsSinkParams
# from robusta.core.sinks.robusta.robusta_sink_params import RobustaSinkConfigWrapper, RobustaSinkParams
# from robusta.core.sinks.slack.slack_sink_params import SlackSinkConfigWrapper, SlackSinkParams


class SinkBaseParams(BaseModel):
    name: str


class SlackSinkParams(SinkBaseParams):
    slack_channel: str
    api_key: str


class SlackSinkConfigWrapper(BaseModel):
    slack_sink: SlackSinkParams


class MsTeamsSinkParams(SinkBaseParams):
    webhook_url: str


class MsTeamsSinkConfigWrapper(BaseModel):
    ms_teams_sink: MsTeamsSinkParams


class RobustaSinkParams(SinkBaseParams):
    token: str


class RobustaSinkConfigWrapper(BaseModel):
    robusta_sink: RobustaSinkParams
